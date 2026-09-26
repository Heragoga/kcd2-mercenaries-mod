# AI

C++ class(es): `CScriptBindAI`, `CScriptBind_AI`
Reached from Lua as `AI.FunctionName(...)`.
305 documented function(s); 11 additional undocumented function(s) found in retail/runtime.

## Functions

### AbortAction

```lua
AI.AbortAction(userId [, actionId ])
```

Aborts execution of an action if actionId is specified, or aborts execution of all actions if actionId is nil or 0

| Param | Description |
|---|---|
| userId | entity id of the user which AI action is aborted |
| actionId *(optional)* | id of action to be aborted or 0 (or nil) to abort all actions on specified entity |

docs: y · retail: confirmed (binary, runtime dump)

### AddAggressiveTarget

```lua
AI.AddAggressiveTarget(entityId, targetId)
```

Add the target Id as an aggressive potential target to the entity's list.

| Param | Description |
|---|---|
| entityId | AI's entity id |
| targetId | Target to add to the list |

Returns: true if updated

docs: y · retail: confirmed (binary, runtime dump)

### AddCombatClass

```lua
AI.AddCombatClass()
```

C++: `int AddCombatClass (IFunctionHandler* pH )`

Creates new combat class.

docs: y · retail: confirmed (binary, runtime dump)

### AddCoverEntity

```lua
AI.AddCoverEntity()
```

C++: `int AddCoverEntity (IFunctionHandler* pH , ScriptHandle entityID )`

This is AddCoverEntity, a member of class CScriptBind_AI.

docs: y · retail: confirmed (binary, runtime dump, vanilla×1 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/EntityCommon.lua`))

### AddFormationPoint

```lua
AI.AddFormationPoint(name, sightangle, distance, offset, [unit_class [,distanceAlt, offsetAlt]])
```

Adds a follow-type node to a formation descriptor.

| Param | Description |
|---|---|
| name | name of the formation descriptor |
| sightangle | angle of sight of the node (-180,180; 0 = the guy looks forward) |
| distance | distance from the formation's owner |
| offset | X offset along the following line (negative = left, positive = right) |
| unit_class | class of soldier (see eSoldierClass definition in IAgent.h) |
| distanceAlt | alternative distance from the formation owner (if 0, distanceAlt and offsetAlt will be set respectively to distance and offset)</param |
| offsetAlt *(optional)* | alternative X offset |

docs: y · retail: confirmed (binary, runtime dump)

### AddFormationPointFixed

```lua
AI.AddFormationPointFixed(name, sightangle, x, y, z [,unit_class])
```

Adds a node with a fixed offset to a formation descriptor.

| Param | Description |
|---|---|
| name | name of the formation descriptor |
| sightangle | angle of sight of the node (-180,180; 0 = the guy looks forward) |
| x, y, z | offset from formation owner |
| unit_class | class of soldier (see eSoldierClass definition in IAgent.h) |

docs: y · retail: confirmed (binary, runtime dump)

### AddPatternBranch

```lua
AI.AddPatternBranch(nodeName, method, branchNode1, branchNode2, ..., branchNodeN)
```

Creates a branch pattern at the specified node. When the entity has approached the specified node (nodeName), and it is time to choose a new point, the rules defined by this function will be used to select the new point. This function allows to associate multiple target points and an evaluation rule.

| Param | Description |
|---|---|
| nodeName | name of the node to add the branches. |
| method | The method to choose the next node when the node is reached. Should be one of the following: |
| AITRACKPAT_CHOOSE_ALWAYS | Chooses on node from the list in linear sequence. |
| AITRACKPAT_CHOOSE_LESS_DEFORMED | Chooses the least deformed point in the list. Each node is associated with a deformation value (percentage) which describes how much it was required to move in order to stay within the physical world. These deformation values are summed down to the parent nodes so that deformation at the end of the hierarchy will be caught down the hierarchy. |
| AITRACKPAT_CHOOSE_RANDOM | Chooses one point in the list randomly. |

docs: y · retail: unconfirmed

### AddPatternNode

```lua
AI.AddPatternNode(nodeName, offsetx, offsety, offsetz, flags, [parent], [signalValue])
```

Adds point to the track pattern. When validating the points test is made from the start position to the end position. ! Start position is either the pattern origin or in case the parent is provided, the parent position. The end position ! is either relative offset from the start position or offset from the pattern origin, this is chosen based on the node flag. ! The offset is clamped to the physical world based on the test method. ! The points will be evaluated in the same oder they are added to the descriptor, and hte system does not try to correct the ! evaluation order. In case hierarchies are used (parent name is defined) it is up to the pattern creator to make sure the ! nodes are created in such order that the parent is added before it is referenced. !

If zero offset is used, the node will become an alias, that is it will not be validated and the parent position and deformation value is used directly.

| Param | Description |
|---|---|
| nodeName | name of the new point, the point names are local to the pattern that is currently being specified. |
| offsetx, offsety, offsetz | The offset from the start position or from the pattern center, see AITRACKPAT_NODE_ABSOLUTE. |
| flags | Defines the node evaluation flags, the flags are as follows and can be combined: ! AITRACKPAT_NODE_START - If this flag is set, this node can be used as the first node in the pattern. There can be multiple start nodes. In that case the closest one is chosen. ! AITRACKPAT_NODE_ABSOLUTE - If this flag is set, the offset is interpret as an offset from the pattern center, otherwise the offset is offset from the start position. ! AITRACKPAT_NODE_SIGNAL - If this flag is set, a signal "OnReachedTrackPatternNode" will be send when the node is reached. ! AITRACKPAT_NODE_STOP - If this flag is set, the advancing will be stopped, it can be continue by calling entity:ChangeAIParameter( AIPARAM_TRACKPATTERN_ADVANCE, 1 ). ! AITRACKPAT_NODE_DIRBRANCH - The default direction at each pattern node is direction from the node position to the center of the pattern ! If this flag is set, the direction will be average direction to the branch nodes. |
| parent *(optional)* | If this parameter is set, the start position is considered to be the parent node position instead of the pattern center. |
| signalValue *(optional)* | If the signal flag is set, this value will be passed as signal parameter, it is accessible from the signal handler in data.iValue. |

docs: y · retail: unconfirmed

### AddPersonallyHostile

```lua
AI.AddPersonallyHostile(entityID, hostileID)
```

C++: `int AddPersonallyHostile (IFunctionHandler* pH , ScriptHandle entityID , ScriptHandle hostileID )`

docs: y · retail: confirmed (binary, runtime dump)

### AddRange

```lua
AI.AddRange()
```

C++: `int AddRange (IFunctionHandler* pH , ScriptHandle entityID , float range , const char * enterSignal , const char * leaveSignal )`

This is AddRange, a member of class CScriptBind_AI.

docs: y · retail: unconfirmed

### AgentLookAtPos

```lua
AI.AgentLookAtPos(entityId, pos)
```

Makes the entityId look at certain position.

| Param | Description |
|---|---|
| entityId | AI's entity id. |
| fov | vec3 to look at |

docs: y · retail: confirmed (binary, runtime dump)

### Animation

```lua
AI.Animation()
```

C++: `int Animation (IFunctionHandler * pH )`

docs: y · retail: confirmed (binary, runtime dump)

### AssignPathTypeToSOUser

```lua
AI.AssignPathTypeToSOUser()
```

C++: `int AssignPathTypeToSOUser (IFunctionHandler* pH )`

This is AssignPathTypeToSOUser, a member of class CScriptBind_AI.

docs: y · retail: confirmed (binary, runtime dump, vanilla×1 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/AI/pathfindProperties.lua`))

### AutoDisable

```lua
AI.AutoDisable()
```

C++: `int AutoDisable (IFunctionHandler * pH )`

AutoDisable

docs: y · retail: confirmed (binary, runtime dump, vanilla×4 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/AI/AISpawner.lua`))

### BeginGoalPipe

```lua
AI.BeginGoalPipe(szPipeName)
```

Creates a goal pipe and allows to start filling it.

| Param | Description |
|---|---|
| szPipeName | goal pipe name |

docs: y · retail: confirmed (binary, runtime dump)

### BeginGroup

```lua
AI.BeginGroup()
```

C++: `int BeginGroup (IFunctionHandler* pH )`

to define group of goals.

docs: y · retail: confirmed (runtime dump)

### BeginTrackPattern

```lua
AI.BeginTrackPattern(patternName, flags, validationRadius, stateTresholdMin?, stateTresholdMax?, globalDeformTreshold?, localDeformTreshold?, exposureMod?, randomRotAng?)
```

[stateTresholdMax], [globalDeformTreshold], [localDeformTreshold], [exposureMod], [randomRotAng] )

Begins definition of a new track pattern descriptor. The pattern is created bu calling ! the AI.AddPatternPoint() and AI.AddPatternBranch() functions, and finalised by calling ! the AI.EndTrackPattern(). !

| Param | Description |
|---|---|
| patternName | name of the new track pattern descriptor |
| flags | The functionality flags of the track pattern. ! Validation: ! The validation method describes how the pattern is validated to fit the physical world. ! Should be one of: ! AITRACKPAT_VALIDATE_NONE - no validation at all. ! AITRACKPAT_VALIDATE_SWEPTSPHERE - validate using swept sphere tests, the spehre radius is validation ! radius plus the entity pass radius. ! AITRACKPAT_VALIDATE_RAYCAST - validate using raycasting, the hit position is pulled back by the amount ! of validation radius plus the entity pass radius. ! Aligning: ! When the pattern is selected to be used the alignment of the patter ncan be changed. ! The alignment can be combination of the following. The descriptions are in order they are evaluated. ! AITRACKPAT_ALIGN_TO_TARGET - Align the pattern so that the y-axis will ! point towards the target each time it is set. If the agent does not have valid attention target ! at the time the pattern is set the pattern will be aligned to the world. ! AITRACKPAT_ALIGN_RANDOM - Align the pattern randonly each time it is set. ! The rotation ranges are set using SetRandomRotation(). |
| validationRadius | the validation radius is added to the entity pass radius when validating ! the pattern along the offsets. |
| stateTresholdMin *(optional)* | If the state of the pattern is 'enclosed' (high deformation) and ! the global deformation < stateTresholdMin, the state becomes exposed. Default 0.35. |
| stateTresholdMax *(optional)* | If the state of the pattern is 'exposed' (low deformation) and ! the global deformation > stateTresholdMax, the state becomes enclosed. Default 0.4. |
| globalDeformTreshold *(optional)* | the deformation of the whole pattern is tracked in range [0..1]. ! This treshold value can be used to clamp the bottom range, so that values in range [trhd..1] becomes [0..1], default 0.0. |
| localDeformTreshold *(optional)* | the deformation of the each node is tracked in range [0..1]. ! This treshold value can be used to clamp the bottom range, so that values in range [trhd..1] becomes [0..1], default 0.0. |
| exposureMod *(optional)* | the exposure modifier allows to take the node exposure (how much it is seen by ! the tracked target) into account when branching. The modifier should be in range [-1..1], -1 means to ! favor unseen nodes, and 1 means to favor seen, exposed node. Default 0 (no effect). |
| randomRotAng *(optional)* | each time the pattern is set, it can be optionally rotated randomly. ! This parameter allows to define angles (in degrees) around each axis. The rotation is performed in XYZ order. |

docs: y · retail: unconfirmed

### BehaviorEvent

```lua
AI.BehaviorEvent()
```

C++: `int BehaviorEvent (IFunctionHandler* pH )`

This is BehaviorEvent, a member of class CScriptBind_AI.

docs: y · retail: confirmed (binary, runtime dump)

### BreakEvent

```lua
AI.BreakEvent()
```

C++: `int BreakEvent (IFunctionHandler* pH , ScriptHandle entityID , Vec3 pos , float radius )`

This is BreakEvent, a member of class CScriptBind_AI.

docs: y · retail: confirmed (binary, runtime dump, vanilla×3 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/Physics/BreakableObject.lua`))

### CanFireInStance

```lua
AI.CanFireInStance(entityId, stance)
```

Returns if AI can fire at his target in the given stance at his current position

| Param | Description |
|---|---|
| entityId | AI's entity id |
| stance | Stance Id (STANCE_*) CanFireInStance |

docs: y · retail: confirmed (binary, runtime dump)

### CanMelee

```lua
AI.CanMelee(entityId)
```

returns 1 if the AI is able to do melee attack.

CanMelee

| Param | Description |
|---|---|
| entityId | AI's entity id |

docs: y · retail: confirmed (binary, runtime dump)

### CanMoveStraightToPoint

```lua
AI.CanMoveStraightToPoint(entityId, position)
```

Returns true if the entity can move to the specified position in a straight line (no multiple segment path necessary)

| Param | Description |
|---|---|
| entityId | AI's entity id |
| position | the position to check |

Returns: true if the position can be reached in a straight line CanMoveStraightToPoint

docs: y · retail: confirmed (binary, runtime dump, mod×5)

> **Verified note:** Treat as a hint, not a walkability oracle: it flipped to false exactly where a runtime-built wall stood, but also returned true for a point measured 40 m underground. -- kcd2/world-and-physics.md#the-ai-lua-table (verified in game)

### ChangeFormation

```lua
AI.ChangeFormation(entityId, name [,scale])
```

Changes the formation descriptor for the current formation of given entity's group (if there is a formation).

| Param | Description |
|---|---|
| entityId | entity id of which group the formation is changed |
| name | name of the formation descriptor |
| scale *(optional)* | scale factor (1 = default) |

Returns: true if the formation change was successful

docs: y · retail: confirmed (binary, runtime dump)

### ChangeMovementAbility

```lua
AI.ChangeMovementAbility(entityId, paramEnum, paramValue)
```

Changes an enumerated AI movement ability parameter.

| Param | Description |
|---|---|
| entityId | entity id |
| paramEnum | the parameter to change, should be one of the following: |
| AIMOVEABILITY_OPTIMALFLIGHTHEIGHT | optimal flight height while finding path (meters). |
| AIMOVEABILITY_MINFLIGHTHEIGHT | minimum flight height while finding path (meters). |
| AIMOVEABILITY_MAXFLIGHTHEIGHT | maximum flight height while finding path (meters). |
| paramValue | new parameter value, see above for type and meaning. |

docs: y · retail: confirmed (binary, runtime dump)

### ChangeParameter

```lua
AI.ChangeParameter(entityId, paramEnum, paramValue)
```

Changes an enumerated AI parameter.

| Param | Description |
|---|---|
| entityId | entity id |
| paramEnum | the parameter to change, should be one of the following: |
| AIPARAM_SIGHTRANGE | sight range in (meters). |
| AIPARAM_ATTACKRANGE | attack range in (meters). |
| AIPARAM_ACCURACY | firing accuracy (real [0..1]). |
| AIPARAM_AGGRESION | aggression (real [0..1]). |
| AIPARAM_GROUPID | group id (integer). |
| AIPARAM_FOV_PRIMARY | primary field of vision (degrees). |
| AIPARAM_FOV_SECONDARY | pheripheral field of vision (degrees). |
| AIPARAM_COMMRANGE | communication range (meters). |
| AIPARAM_FWDSPEED | forward speed (vehicles only). |
| AIPARAM_RESPONSIVENESS | responsiveness (real). |
| AIPARAM_SPECIES | entity species (integer). |
| AIPARAM_TRACKPATTERN | track pattern name (string). |
| AIPARAM_TRACKPATTERN_ADVANCE | track pattern advancing (0 = stop, 1 = advance). |
| paramValue | new parameter value, see above for type and meaning. |

docs: y · retail: confirmed (binary, runtime dump, vanilla×1 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/EntityCommon.lua`))

### ChangeRange

```lua
AI.ChangeRange()
```

C++: `int ChangeRange (IFunctionHandler* pH , ScriptHandle entityID , int rangeID , float distance )`

This is ChangeRange, a member of class CScriptBind_AI.

docs: y · retail: unconfirmed

### CheckForFriendlyAgentsAroundPoint

```lua
AI.CheckForFriendlyAgentsAroundPoint(entityID, point, radius)
```

C++: `int CheckForFriendlyAgentsAroundPoint (IFunctionHandler* pH , ScriptHandle entityID , Vec3 point , float radius )`

docs: y · retail: confirmed (binary, runtime dump)

### CheckMeleeDamage

```lua
AI.CheckMeleeDamage(entityId, targetId, radius, minheight, maxheight, angle)
```

returns 1 if the AI performing melee is actually hitting target.

CheckMeleeDamage

| Param | Description |
|---|---|
| entityId | AI's entity id |
| targetId | AI's target entity id |
| radius | max distance in 2d to target |
| minheight | min distance in height |
| maxheight | max distance in height |
| angle | FOV to include target |

Returns: (distance,angle) pair between entity and target (degrees) if melee is possible, nil otherwise

docs: y · retail: confirmed (binary, runtime dump)

### CheckVehicleColision

```lua
AI.CheckVehicleColision()
```

C++: `int CheckVehicleColision (IFunctionHandler * pH )`

docs: y · retail: confirmed (binary, runtime dump)

### ClearAnimationTag

```lua
AI.ClearAnimationTag(entityId, tagName)
```

Clear a Mannequin animation tag group.

In: The function handler (NULL is invalid!) In: The script handle of the entity on which to clear the animation tag. In: The name of any animation tag in the group that we want to clear (case insensitive).

| Param | Description |
|---|---|
| const char* tagName | . |
| entityId | AI's entity |

Returns: A default result code (in Lua: void).

docs: y · retail: confirmed (binary, runtime dump)

### ClearForReload

```lua
AI.ClearForReload(szPipeName)
```

C++: `int ClearForReload (IFunctionHandler* pH )`

Clears all goalpipes from the system.

docs: y · retail: unconfirmed

### ClearPotentialTargets

```lua
AI.ClearPotentialTargets(entityId)
```

Clears all the potential targets from the AI's perception handler.

| Param | Description |
|---|---|
| entityId | AI's entity id |

docs: y · retail: confirmed (binary, runtime dump)

### ClearTempTarget

```lua
AI.ClearTempTarget(entityId)
```

Removes the entity's temporary potential target, so it is no longer considered for target selection.

| Param | Description |
|---|---|
| entityId | AI's entity id |

Returns: true if cleared

docs: y · retail: confirmed (binary, runtime dump)

### ConstrainPointInsideGenericShape

```lua
AI.ConstrainPointInsideGenericShape(position, shapeName[, checkHeight])
```

Returns the nearest point inside specified shape.

| Param | Description |
|---|---|
| position | the position to check |
| shapeName | the name of the shape to use as constraint. |
| checkHeight | (optional) Default=false, if the flag is set the height should be constrained too. ConstrainPointInsideGenericShape |

docs: y · retail: confirmed (binary, runtime dump)

### CreateFormation

```lua
AI.CreateFormation(name)
```

Creates a formation descriptor and adds a fixed node at 0,0,0 (owner's node).

| Param | Description |
|---|---|
| name | name of the new formation descriptor. |

docs: y · retail: confirmed (binary, runtime dump)

### CreateGoalPipe

```lua
AI.CreateGoalPipe(szPipeName)
```

Used for warnings about data/script errors.

Create a sequence of AI atomic commands (a goal pipe) @param desired name of the goal pipe

| Param | Description |
|---|---|
| szPipeName | goal pipe name |

docs: y · retail: confirmed (binary, runtime dump)

### CreateGroupFormation

```lua
AI.CreateGroupFormation(entityId, leaderId)
```

Creates a group formation with leader (or updates leader).

AI.CreateGroupFormation(entityId, leaderId)

| Param | Description |
|---|---|
| entityId | AI's entity |
| leaderId | New leader |

docs: y · retail: confirmed (binary, runtime dump)

### CreateQueryFromTacticalSpec

```lua
AI.CreateQueryFromTacticalSpec()
```

C++: `int CreateQueryFromTacticalSpec (SmartScriptTable specTable )`

This is CreateQueryFromTacticalSpec, a member of class CScriptBind_AI.

docs: y · retail: unconfirmed

### CreateStimulusEvent

```lua
AI.CreateStimulusEvent(entityId, targetId, stimulusName, pData)
```

Creates a target track stimulus event for the entity using the specified data.

| Param | Description |
|---|---|
| ScriptHandle ownerId | Owner's entity id (who owns and is receiving the event) |
| ScriptHandle targetId | Target's entity id (who sent the event, and becomes owner's perceived target) |
| const char* stimulusName | Name of the stimulus event |
| SmartScriptTable pData | Data about the event (see TargetTrackHelpers::SStimulusEvent) |

docs: y · retail: confirmed (binary, runtime dump)

### CreateStimulusEventInRange

```lua
AI.CreateStimulusEventInRange()
```

C++: `int CreateStimulusEventInRange (IFunctionHandler* pH , ScriptHandle targetId , const char * stimulusName , SmartScriptTable dataScriptTable )`

This is CreateStimulusEventInRange, a member of class CScriptBind_AI.

docs: y · retail: confirmed (binary, runtime dump)

### CreateTempGenericShapeBox

```lua
AI.CreateTempGenericShapeBox(center, radius, height, type)
```

Creates a temporary box shaped generic shape (will be destroyed upon AIsystem reset).

CreateTempGenericShapeBox

| Param | Description |
|---|---|
| center | the center of the box |
| radius | the extend of the box in x and y directions. |
| height | the height of the box. |
| type | the AIanchor type of the shape. |

Returns: the name of the shape.

docs: y · retail: confirmed (binary, runtime dump, mod×2)

### DebugReportHitDamage

```lua
AI.DebugReportHitDamage(pVictimEntity, pShooterEntity)
```

Creates a debug report for the hit damage.

DebugReportHitDamage

| Param | Description |
|---|---|
| pVictimEntity | Victim ID. |
| pShooterEntity | Shooter ID. |

docs: y · retail: confirmed (binary, runtime dump)

### DistanceToGenericShape

```lua
AI.DistanceToGenericShape(position, shapeName[, checkHeight])
```

Returns true if the point is inside the specified shape.

| Param | Description |
|---|---|
| position | the position to check |
| shapeName | the name of the shape to test (returned by AI.GetEnclosingGenericShapeOfType) |
| checkHeight | (optional) if the flag is set the height of the shape is tested too. The test will check space between the shape.aabb.min.z and shape.aabb.min.z+shape.height. DistanceToGenericShape |

docs: y · retail: confirmed (binary, runtime dump)

### DropTarget

```lua
AI.DropTarget(entityId, targetId)
```

Clears the target from the AI's perception handler.

| Param | Description |
|---|---|
| entityId | AI's entity id |
| targetId | target's entity id |

docs: y · retail: confirmed (binary, runtime dump)

### EnableCoverFire

```lua
AI.EnableCoverFire(entityId, enable)
```

Enables/disables fire when the FIREMODE_COVER is selected.

EnableCoverFire

| Param | Description |
|---|---|
| entityId | AI's entity id |
| enable | boolean |

docs: y · retail: confirmed (binary, runtime dump)

### EnableFire

```lua
AI.EnableFire(entityId, enable)
```

Enables/disables fire.

EnableFire

| Param | Description |
|---|---|
| entityId | AI's entity id |
| enable | boolean |

docs: y · retail: confirmed (binary, runtime dump)

### EnableUpdateLookTarget

```lua
AI.EnableUpdateLookTarget(entityID, bEnable)
```

C++: `int EnableUpdateLookTarget (IFunctionHandler* pH , ScriptHandle entityID , bool bEnable )`

docs: y · retail: confirmed (binary, runtime dump)

### EnableWeaponAccessory

```lua
AI.EnableWeaponAccessory(entityId, accessory, state)
```

Enables or disables certain weapon accessory usage.

EnableWeaponAccessory

| Param | Description |
|---|---|
| entityId | AI's entity id |
| accessory | enum of the accessory to enable (see EAIWeaponAccessories) |
| state | true/false to enable/disable |

docs: y · retail: confirmed (binary, runtime dump)

### EndGoalPipe

```lua
AI.EndGoalPipe()
```

C++: `int EndGoalPipe (IFunctionHandler* pH )`

Ends creating a goal pipe.

docs: y · retail: confirmed (runtime dump)

### EndGroup

```lua
AI.EndGroup()
```

C++: `int EndGroup (IFunctionHandler* pH )`

Defines the end of a group of goals.

docs: y · retail: confirmed (runtime dump)

### EndTrackPattern

```lua
AI.EndTrackPattern()
```

C++: `int EndTrackPattern (IFunctionHandler* pH )`

Finalizes the track pattern definition. This function should always called to finalize the pattern. ! Failing to do so will cause erratic behavior.

docs: y · retail: unconfirmed

### Error

```lua
AI.Error(szMessage)
```

Used when we really can't handle some data/situation. ! The code following this should struggle on so that the original cause (e.g. data) ! of the problem can be fixed in the editor, but in game this would halt execution. !

Error

| Param | Description |
|---|---|
| szMessage | message line to be displayed in log |

docs: y · retail: confirmed (binary, runtime dump)

### EvalHidespot

```lua
AI.EvalHidespot()
```

C++: `int EvalHidespot (IFunctionHandler * pH )`

docs: y · retail: confirmed (binary, runtime dump)

### EvalPeek

```lua
AI.EvalPeek(entityId [, bGetOptimalSide])
```

Evaluates if an AI object can peek from his current position.

| Param | Description |
|---|---|
| entityId | AI's entity id |
| bGetOptimalSide *(optional)* | If TRUE, and AI object can peek from both sides, will return the ! side that best fits where the attention target currently is |

Returns: -1 - don't need to peek ! 0 - cannot peek ! 1 - can peek from left ! 2 - can peek from right ! 3 - can peek from left & right

docs: y · retail: confirmed (binary, runtime dump)

### Event

```lua
AI.Event()
```

C++: `int Event (IFunctionHandler * pH )`

docs: y · retail: confirmed (binary, runtime dump)

### ExecuteAction

```lua
AI.ExecuteAction(action, participant1 [, participant2 [, ... , participantN ] ])
```

Executes an Action on a set of Participants.

| Param | Description |
|---|---|
| action | Smart Object Action name or id |
| participant1 | entity id of the first Participant in the Action |
| (optional) participant2..N | entity ids of other participants |

docs: y · retail: confirmed (binary, runtime dump)

### FindObjectOfType

```lua
AI.FindObjectOfType(entityId, position, radius, AIObjectType, flags, (optional) returnPosition, (optional) returnDirection)
```

returns the closest AIObject of a given type around a given entity/position; ! once an AIObject is found, it's devalued and can't be found again for some seconds (unless specified in flags). !

static void DrawDebugBox(const AABB& aabb, uint8 r, uint8 g, uint8 b, float t) { Vec3 verts[8];

verts[0].Set(aabb.min.x, aabb.min.y, aabb.min.z); verts[1].Set(aabb.max.x, aabb.min.y, aabb.min.z); verts[2].Set(aabb.max.x, aabb.max.y, aabb.min.z); verts[3].Set(aabb.min.x, aabb.max.y, aabb.min.z);

verts[4].Set(aabb.min.x, aabb.min.y, aabb.max.z); verts[5].Set(aabb.max.x, aabb.min.y, aabb.max.z); verts[6].Set(aabb.max.x, aabb.max.y, aabb.max.z); verts[7].Set(aabb.min.x, aabb.max.y, aabb.max.z);

gEnv->pAISystem->AddDebugLine(verts[0], verts[1], r, g, b, t); gEnv->pAISystem->AddDebugLine(verts[1], verts[2], r, g, b, t); gEnv->pAISystem->AddDebugLine(verts[2], verts[3], r, g, b, t); gEnv->pAISystem->AddDebugLine(verts[3], verts[0], r, g, b, t);

gEnv->pAISystem->AddDebugLine(verts[4], verts[5], r, g, b, t); gEnv->pAISystem->AddDebugLine(verts[5], verts[6], r, g, b, t); gEnv->pAISystem->AddDebugLine(verts[6], verts[7], r, g, b, t); gEnv->pAISystem->AddDebugLine(verts[7], verts[4], r, g, b, t);

gEnv->pAISystem->AddDebugLine(verts[0], verts[4], r, g, b, t); gEnv->pAISystem->AddDebugLine(verts[1], verts[5], r, g, b, t); gEnv->pAISystem->AddDebugLine(verts[2], verts[6], r, g, b, t); gEnv->pAISystem->AddDebugLine(verts[3], verts[7], r, g, b, t);

| Param | Description |
|---|---|
| entityId | AI's entity id as a center position of the search (if 1st parameter is not a vector) |
| position | center position of the search (if 1st parameter is not an entity id) |
| radius | radius inside which the object must be found |
| AIObjectType | AIObject type; see ScriptBindAI.cpp and Scripts/AIAnchor.lua for a complete list of AIObject types available |
| flags | filter for AI Objects to search, which can be the sum of one or more of the following values: ! AIFAF_VISIBLE_FROM_REQUESTER: Requires whoever is requesting the anchor to also have a line of sight to it ! AIFAF_VISIBLE_TARGET: Requires that there is a line of sight between target and anchor ! AIFAF_INCLUDE_DEVALUED: don't care if the object is devalued ! AIFAF_INCLUDE_DISABLED: don't care if the object is disabled |
| (optional) returnPosition | position of the found object |
| (optional) returnDirection | direction of the found object |

Returns: the found AIObject's name (nil if not found)

docs: y · retail: confirmed (binary, runtime dump)

### FindStandbySpotInShape

```lua
AI.FindStandbySpotInShape()
```

C++: `int FindStandbySpotInShape (IFunctionHandler * pH )`

AI.FindStandbySpotInShape(centerPos, targetPos, anchorType);

FindStandbySpotInShape

docs: y · retail: confirmed (binary, runtime dump)

### FindStandbySpotInSphere

```lua
AI.FindStandbySpotInSphere()
```

C++: `int FindStandbySpotInSphere (IFunctionHandler * pH )`

AI.FindStandbySpotInSphere(centerPos, targetPos, anchorType);

FindStandbySpotInSphere

docs: y · retail: confirmed (binary, runtime dump)

### FreeSignal

```lua
AI.FreeSignal(signalType, SignalText, position, radius [, entityID [,signalExtraData]])
```

Sends a signal to anyone in a given radius around a position.

| Param | Description |
|---|---|
| signalType | see AI.Signal |
| signalText | See AI.Signal |
| position | center position {x,y,z}around which the signal is sent |
| radius | radius inside which the signal is sent |
| (optional) entityID | signal is NOT sent to entities which groupID is same as the entity's one |
| (optional) signalExtraData | See AI.Signal |

docs: y · retail: confirmed (binary, runtime dump, vanilla×1 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/Physics/DestroyableObject.lua`))

### Friendly

```lua
AI.Friendly(entityId, entity2Id|AIObjectName)
```

returns true if the two entities are friendly

| Param | Description |
|---|---|
| entityId | 1st AI's entity id entity2Id |AIObjectName - 2nd AI's entity id | 2nd AIobject's name |

Returns: true if the entities are friendly

docs: y · retail: unconfirmed

### GenerateUniqueTacticGroupId

```lua
AI.GenerateUniqueTacticGroupId()
```

C++: `int GenerateUniqueTacticGroupId (IFunctionHandler * pH )`

Returns a unique tactic group Id to use

docs: y · retail: unconfirmed

### GetAIObjectPosition

```lua
AI.GetAIObjectPosition(entityId | AIObjectName)
```

get the given AIObject's position.

| Param | Description |
|---|---|
| entityId | AIObjectName | AI's entity id | AI object name |

Returns: AI Object position vector {x,y,z}

docs: y · retail: confirmed (binary, runtime dump)

### GetAlertness

```lua
AI.GetAlertness()
```

C++: `int GetAlertness (IFunctionHandler * pH )`

docs: y · retail: confirmed (binary, runtime dump)

### GetAnchor

```lua
AI.GetAnchor(entityId, radius, AIAnchorType, searchType [,returnPosition [,returnDirection]])
```

returns the closest Anchor of a given type around a given entity; once an Anchor is found, it's devalued and can't be found again for some seconds (unless specified in flags)

| Param | Description |
|---|---|
| entityId | AI's entity id as a center position of the search |
| radius | radius inside which the object must be found. Alternatively a search range can be specified {min=minRad,max=maxRad}. |
| AIAnchorType | Anchor type; see Scripts/AIAnchor.lua for a complete list of Anchor types available |
| searchType | search type filter, which can be one of the following values: |
| AIANCHOR_NEAREST | (default) the nearest anchor of the given type |
| AIANCHOR_NEAREST_IN_FRONT | the nearest anchor inside the front cone of entity |
| AIANCHOR_NEAREST_FACING_AT | the nearest anchor of given type which is oriented towards entity's attention target (...Dejan? ) |
| AIANCHOR_RANDOM_IN_RANGE | a random anchor of the given type |
| AIANCHOR_NEAREST_TO_REFPOINT | the nearest anchor of given type to the entity's reference point (optional) returnPosition - position of the found object (optional) returnDirection - direction of the found object |

Returns: the found Anchor's name (nil if not found)

docs: y · retail: confirmed (binary, runtime dump)

### GetAttentionTargetAIType

```lua
AI.GetAttentionTargetAIType(entityId)
```

returns the given entity's attention target AI type (AIOBJECT_*).

| Param | Description |
|---|---|
| entityId | AI's entity id |

Returns: attention target's type (AIOBJECT_NONE if no target)

docs: y · retail: confirmed (binary, runtime dump)

### GetAttentionTargetDirection

```lua
AI.GetAttentionTargetDirection(entityId, returnDir)
```

returns the given entity's attention target's direction.

| Param | Description |
|---|---|
| entityId | AI's entity id |

Returns: Dir - vector {x,y,z} passed as a return value (attention target 's direction)

docs: y · retail: confirmed (binary, runtime dump)

### GetAttentionTargetDistance

```lua
AI.GetAttentionTargetDistance(entityId)
```

returns the given entity's attention target's distance to the entity.

| Param | Description |
|---|---|
| entityId | AI's entity id |

Returns: distance to the attention target (nil if no target)

docs: y · retail: confirmed (binary, runtime dump)

### GetAttentionTargetEntity

```lua
AI.GetAttentionTargetEntity(entityId)
```

returns the given entity's attention target entity (if it is an entity) or ! the owner entity of the attention target if it is a dummy object (if there is an owner entity). !

| Param | Description |
|---|---|
| entityId | AI's entity id |

Returns: attention target's entity

docs: y · retail: confirmed (binary, runtime dump)

### GetAttentionTargetOf

```lua
AI.GetAttentionTargetOf(entityId)
```

returns the given entity's attention target.

| Param | Description |
|---|---|
| entityId | AI's entity id |

Returns: attention target's name (nil if no target)

docs: y · retail: confirmed (binary, runtime dump)

### GetAttentionTargetPosition

```lua
AI.GetAttentionTargetPosition(entityId, returnPos)
```

returns the given entity's attention target's position.

| Param | Description |
|---|---|
| entityId | AI's entity id |

Returns: Pos - vector {x,y,z} passed as a return value (attention target 's position)

docs: y · retail: confirmed (binary, runtime dump)

### GetAttentionTargetThreat

```lua
AI.GetAttentionTargetThreat(entityID)
```

C++: `int GetAttentionTargetThreat (IFunctionHandler* pH , ScriptHandle entityID )`

docs: y · retail: confirmed (binary, runtime dump)

### GetAttentionTargetType

```lua
AI.GetAttentionTargetType(entityId)
```

returns the given entity's attention target type (AITARGET_*).

| Param | Description |
|---|---|
| entityId | AI's entity id |

Returns: attention target's type (AITARGET_NONE if no target)

docs: y · retail: confirmed (binary, runtime dump)

### GetAttentionTargetViewDirection

```lua
AI.GetAttentionTargetViewDirection(entityId, returnDir)
```

returns the given entity's attention target's view direction.

| Param | Description |
|---|---|
| entityId | AI's entity id |

Returns: Dir - vector {x,y,z} passed as a return value (attention target 's direction)

docs: y · retail: confirmed (binary, runtime dump)

### GetBeaconPosition

```lua
AI.GetBeaconPosition(entityId | AIObjectName, returnPos)
```

get the beacon's position for the given entity/object's group.

| Param | Description |
|---|---|
| entityId | AIObjectName | AI's entity id | AI object name |
| returnPos | vector {x,y,z} where the beacon position will be set |

Returns: true if the beacon has been found and the position set

docs: y · retail: confirmed (binary, runtime dump)

### GetBehaviorBlackBoard

```lua
AI.GetBehaviorBlackBoard(entity)
```

retrieves given AIActor current behaviour's black board (a Lua table).

GetBehaviorBlackBoard

| Param | Description |
|---|---|
| entityId or entityName | some kind of AIActors's identifier |

Returns: black board - if there was one ! nil - Otherwise

docs: y · retail: confirmed (binary, runtime dump)

### GetBehaviorVariable

```lua
AI.GetBehaviorVariable(entity, variableName, value)
```

C++: `int GetBehaviorVariable (IFunctionHandler* pH , ScriptHandle entityId , const char * variableName )`

Returns a behavior variable for the specified actor.

docs: y · retail: confirmed (binary, runtime dump)

### GetBiasedDirection

```lua
AI.GetBiasedDirection(entityId)
```

Get biased direction of certain point.

| Param | Description |
|---|---|
| entityId | AI's entity GetBiasedDirection |

docs: y · retail: confirmed (binary, runtime dump)

### GetCoordinationEnvironment

```lua
AI.GetCoordinationEnvironment(coordinationID)
```

C++: `int GetCoordinationEnvironment (IFunctionHandler* pH , ScriptHandle coordinationID )`

docs: y · retail: unconfirmed

### GetCoordinationInput

```lua
AI.GetCoordinationInput(coordinationID, name)
```

C++: `int GetCoordinationInput (IFunctionHandler* pH , ScriptHandle coordinationID , const char * name )`

docs: y · retail: unconfirmed

### GetCurrentCoordination

```lua
AI.GetCurrentCoordination(entityID)
```

C++: `int GetCurrentCoordination (IFunctionHandler* pH , ScriptHandle entityID )`

docs: y · retail: unconfirmed

### GetCurrentCoordinationName

```lua
AI.GetCurrentCoordinationName(entityID)
```

C++: `int GetCurrentCoordinationName (IFunctionHandler* pH , ScriptHandle entityID )`

docs: y · retail: unconfirmed

### GetCurrentHideAnchor

```lua
AI.GetCurrentHideAnchor(entityId)
```

Returns the name of the current anchor the entity is using for cover.

GetCurrentHideAnchor

| Param | Description |
|---|---|
| entityId | AI's entity id |

docs: y · retail: confirmed (binary, runtime dump)

### GetDirectAttackPos

```lua
AI.GetDirectAttackPos(entityId, searchRange, minAttackRange)
```

Returns a cover point which can be used to directly attack the attention target. Useful for choosing attack position for RPGs and such. Returns nil if no attack point is available.

| Param | Description |
|---|---|
| entityId | AI's entity id |
| AIAnchorType | Anchor type; see Scripts/AIAnchor.lua for a complete list of Anchor types available |
| maxDist | search range |

docs: y · retail: unconfirmed

### GetDirLabelToPoint

```lua
AI.GetDirLabelToPoint(entityId, point)
```

Returns a direction label (front=0, back=1, left=2, right_3, above=4, -1=invalid) to the specified point.

| Param | Description |
|---|---|
| entityId | AI's entity id |
| point | point to evaluate. |

docs: y · retail: confirmed (binary, runtime dump)

### GetDirOnPathBySegNo

```lua
AI.GetDirOnPathBySegNo(pathname, segNo)
```

C++: `int GetDirOnPathBySegNo (IFunctionHandler* pH )`

returns path direction at the point identified by segNo segNo - segment ratio pathname - designer's path name

docs: y · retail: unconfirmed

### GetDistanceAlongPath

```lua
AI.GetDistanceAlongPath(entityId1, entityid2)
```

returns the distance between entity1 and entity2, along entity1's path.

GetDistanceAlongPath

| Param | Description |
|---|---|
| entityId1 | AI's entity1 id |
| entityId2 | AI's entity2 id |

Returns: distance along entity1 path; distance value would be negative if the entity2 is ahead along the path

docs: y · retail: confirmed (binary, runtime dump)

### GetDistanceToClosestGroupMember

```lua
AI.GetDistanceToClosestGroupMember(entityId)
```

C++: `int GetDistanceToClosestGroupMember (IFunctionHandler* pH , ScriptHandle entityId )`

docs: y · retail: confirmed (binary, runtime dump)

### GetEnclosingGenericShapeOfType

```lua
AI.GetEnclosingGenericShapeOfType(position, type[, checkHeight])
```

Returns the name of the first shape that is enclosing the specified point and is of specified type

| Param | Description |
|---|---|
| position | the position to check |
| type | the type of the shapes to check against (uses anchor types). |
| checkHeight | (optional) Default=false, if the flag is set the height of the shape is tested too. The test will check space between the shape.aabb.min.z and shape.aabb.min.z+shape.height. GetEnclosingGenericShapeOfType |

docs: y · retail: confirmed (binary, runtime dump)

### GetEnclosingSpace

```lua
AI.GetEnclosingSpace()
```

C++: `int GetEnclosingSpace (IFunctionHandler * pH )`

Returns: the estimated surrounding navigable space in meters.

docs: y · retail: confirmed (binary, runtime dump)

### GetEntityFromParam

```lua
AI.GetEntityFromParam()
```

C++: `IEntity * GetEntityFromParam (IFunctionHandler * pH , int i )`

Fetch entity pointer from script parameter

Fetch entity pointer from script parameter

docs: y · retail: unconfirmed

### GetEntityIdFromParam

```lua
AI.GetEntityIdFromParam()
```

C++: `EntityId GetEntityIdFromParam (IFunctionHandler * pH , int i )`

Fetch entity ID from script parameter

Fetch entity ID from script parameter

docs: y · retail: unconfirmed

### GetEntityTacticGroupId

```lua
AI.GetEntityTacticGroupId(entity)
```

Gets which tactic group Id an entity belongs to

| Param | Description |
|---|---|
| Return | The tactic group Id or nil on error |

docs: y · retail: unconfirmed

### GetExtraPriority

```lua
AI.GetExtraPriority(enemyEntityId)
```

get an extra priority value to the entity which is given by enemyEntityId.

| Param | Description |
|---|---|
| enemyEntityId | AI's entity id |

docs: y · retail: confirmed (binary, runtime dump)

### GetFactionOf

```lua
AI.GetFactionOf(entityID)
```

C++: `int GetFactionOf (IFunctionHandler* pH , ScriptHandle entityID )`

Returns: The faction of the specified entity.

docs: y · retail: confirmed (binary, runtime dump, vanilla×4 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/Triggers/AreaTrigger.lua`))

### GetFlyingVehicleFlockingPos

```lua
AI.GetFlyingVehicleFlockingPos()
```

C++: `int GetFlyingVehicleFlockingPos (IFunctionHandler * pH )`

docs: y · retail: confirmed (binary, runtime dump)

### GetFormationLookingPoint

```lua
AI.GetFormationLookingPoint(entityId)
```

Gets the looking point position inside the formation.

vec3 AI.GetFormationPosition(entityId)

| Param | Description |
|---|---|
| entityId | AI's entity |

Returns: v3 - Table with format {x,y,z} storing the looking point position

docs: y · retail: confirmed (binary, runtime dump)

### GetFormationPointPosition

```lua
AI.GetFormationPointPosition(entityId, pos)
```

Gets the AI's formation point position.

| Param | Description |
|---|---|
| entityId | AI's entity id |
| pos | return value- position of entity AI's current formation point if there is |

Returns: true if the formation point has been found

docs: y · retail: confirmed (binary, runtime dump)

### GetFormationPosition

```lua
AI.GetFormationPosition(entityId)
```

Gets the Relative position inside the formation.

vec3 AI.GetFormationPosition(entityId)

| Param | Description |
|---|---|
| entityId | AI's entity |

Returns: v3 - Table with format {x,y,z} storing the relative position

docs: y · retail: confirmed (binary, runtime dump)

### GetForwardDir

```lua
AI.GetForwardDir()
```

C++: `int GetForwardDir (IFunctionHandler * pH )`

Attention Target / perception related functions

docs: y · retail: confirmed (binary, runtime dump)

### GetGroupAlertness

```lua
AI.GetGroupAlertness()
```

C++: `int GetGroupAlertness (IFunctionHandler * pH )`

docs: y · retail: confirmed (binary, runtime dump)

### GetGroupAveragePosition

```lua
AI.GetGroupAveragePosition(entityId, properties, returnPos)
```

gets the average position of the (leader's) group members

| Param | Description |
|---|---|
| entityId | AI's entity id which group/leader is determined |
| unitProperties | binary mask of unit properties type for which the attack is requested ! (in the form of UPR_* + UPR* i.e. UPR_COMBAT_GROUND + UPR_COMBAT_FLIGHT) ! see IAgent.h for definition of unit properties UPR_* |

Returns: Pos returned average position

docs: y · retail: confirmed (binary, runtime dump)

### GetGroupCount

```lua
AI.GetGroupCount(entityId, flags, type)
```

returns the given entity's group members count

| Param | Description |
|---|---|
| entityId | AI's entity id or groupId - AI's group id |
| flags | combination of following flags: |
| GROUP_ALL | Returns all agents in the group (default). |
| GROUP_ENABLED | Returns only the count of enabled agents (exclusive with all). |
| GROUP_MAX | Returns the maximum number of agents during the game (can be combined with all or enabled). |
| type | allows to filter to return only specific AI objects by type (cannot be used in together with GROUP_MAX flag). |

Returns: group members count

docs: y · retail: confirmed (binary, runtime dump)

### GetGroupMember

```lua
AI.GetGroupMember(entityId|groupId, idx, flags, type)
```

returns the idx-th entity in the given group

| Param | Description |
|---|---|
| idx | index (1..N) |
| flags | combination of following flags: |
| GROUP_ALL | Returns all agents in the group (default). |
| GROUP_ENABLED | Returns only the count of enabled agents (exclusive with all). |
| type | allows to filter to return only specific AI objects by type (cannot be used in together with GROUP_MAX flag). |

Returns: script handler of idx-th entity (null if idx is out of range)

docs: y · retail: confirmed (binary, runtime dump)

### GetGroupOf

```lua
AI.GetGroupOf(entityId)
```

returns the given entity's group id.

| Param | Description |
|---|---|
| entityId | AI's entity id |

Returns: group id of given entity

docs: y · retail: confirmed (binary, runtime dump)

### GetGroupScopeUserCount

```lua
AI.GetGroupScopeUserCount(entityID, bAllowLowerBodyToTurn)
```

| Param | Description |
|---|---|
| const char* groupScopeName | the group scope name. |
| entityId | entity id of the agent you want to access the group scope for. |

Returns: The amount of actors inside the group scope (>= 0) or nil if an error occurred.

docs: y · retail: confirmed (binary, runtime dump)

### GetGroupScriptTable

```lua
AI.GetGroupScriptTable(groupID)
```

C++: `int GetGroupScriptTable (IFunctionHandler * pH , int groupID )`

docs: y · retail: confirmed (binary, runtime dump)

### GetGroupSpatialProperties

```lua
AI.GetGroupSpatialProperties()
```

C++: `bool GetGroupSpatialProperties (IAIObject* pRequester , float & offset , Vec3& avgGroupPos , Vec3& targetPos , Vec3& dirToTarget , Vec3& normToTarget )`

docs: y · retail: unconfirmed

### GetGroupTarget

```lua
AI.GetGroupTarget(entityId [,bHostileOnly [,bLiveOnly]])
```

Returns the most threatening attention target amongst the agents in the given entity's group. (see IAgent.h for definition of alert status)

| Param | Description |
|---|---|
| entityId | AI's entity id which group is determined |
| bHostileOnly *(optional)* | filter only hostile targets in group |
| bLiveOnly *(optional)* | filter only live targets in group (entities) |

docs: y · retail: confirmed (binary, runtime dump)

### GetGroupTargetCount

```lua
AI.GetGroupTargetCount(entityId [,bHostileOnly [,bLiveOnly]])
```

Returns the number of attention targets amongst the agents in the given entity's group.

| Param | Description |
|---|---|
| entityId | AI's entity id which group is determined |
| bHostileOnly *(optional)* | filter only hostile targets in group |
| bLiveOnly *(optional)* | filter only live targets in group (entities) |

docs: y · retail: confirmed (binary, runtime dump)

### GetGroupTargetEntity

```lua
AI.GetGroupTargetEntity(groupID)
```

C++: `int GetGroupTargetEntity (IFunctionHandler * pH , int groupID )`

docs: y · retail: confirmed (binary, runtime dump)

### GetGroupTargetThreat

```lua
AI.GetGroupTargetThreat(groupID)
```

C++: `int GetGroupTargetThreat (IFunctionHandler * pH , int groupID )`

docs: y · retail: confirmed (binary, runtime dump)

### GetGroupTargetType

```lua
AI.GetGroupTargetType(groupID)
```

C++: `int GetGroupTargetType (IFunctionHandler * pH , int groupID )`

docs: y · retail: confirmed (binary, runtime dump)

### GetHeliAdvancePoint

```lua
AI.GetHeliAdvancePoint()
```

C++: `int GetHeliAdvancePoint (IFunctionHandler* pH )`

Helicopter combat, should be merged with GetAlienApproachParams

docs: y · retail: confirmed (binary, runtime dump)

### GetLastSmartObjectExitPoint

```lua
AI.GetLastSmartObjectExitPoint(userEntityId, pos)
```

Returns the last used navigational smart object's exit point

| Param | Description |
|---|---|
| usedEntityId | entity id of the user for which its last used smart object is needed |
| pos | returned position of last used navigational smartobject's exit point |

Returns: true if the operation was successful

docs: y · retail: unconfirmed

### GetLastUsedSmartObject

```lua
AI.GetLastUsedSmartObject(userEntityId)
```

Returns the last used smart object.

| Param | Description |
|---|---|
| usedEntityId | entity id of the user for which its last used smart object is needed |

Returns: nil if there's no last used smart object (or if an error has occurred) ! or the script table of the entity which is the last used smart object

docs: y · retail: confirmed (binary, runtime dump)

### GetLeader

```lua
AI.GetLeader(groupID | entityID)
```

returns the leader's name of the given groupID / entity

| Param | Description |
|---|---|
| groupID | group id |
| entityID | entity (id) of which we want to find the leader |

docs: y · retail: confirmed (binary, runtime dump)

### GetMemoryFireType

```lua
AI.GetMemoryFireType(entityId)
```

Returns how the puppet handles firing at its memory target

| Param | Description |
|---|---|
| entityId | AI's entity id |

Returns: Memory fire type (see EMemoryFireType)

docs: y · retail: confirmed (binary, runtime dump)

### GetNavigationType

```lua
AI.GetNavigationType(entityId)
```

returns the navigation type value at the specified entity's position, given the entity navigation properties.

| Param | Description |
|---|---|
| entityId | AI's entity id |

Returns: navigation type at the entity's position (NAV_TRIANGULAR,NAV_WAYPOINT_HUMAN,NAV_ROAD,NAV_VOLUME,NAV_WAYPOINT_3DSURFACE, ! NAV_FLIGHT,NAV_SMARTOBJECT) see IAISystem::ENavigationType definition

docs: y · retail: confirmed (binary, runtime dump, mod×2)

### GetNearestEntitiesOfType

```lua
AI.GetNearestEntitiesOfType(entityId|objectname|position, AIObjectType, maxObjects, returnList [,objectFilter [,radius]])
```

returns a list of the closest N entities of a given AIObjkect type associated the found objects are then devalued.

| Param | Description |
|---|---|
| entityId | objectname |position | AI's entity id | name| position as a center position of the search |
| radius | radius inside which the entities must be found |
| AIObjectType | AIObject type; see ScriptBindAI.cpp and Scripts/AIAnchor.lua for a complete list of AIObject types available |
| maxObjects | maximum number of objects to find |
| return list | Lua table which will be filled up with the list of the found entities (Lua handlers) |
| (optional) objectFilter | search type filter, which can be the sum of one or more of the following values: ! AIOBJECTFILTER_SAMEFACTION: AI objects of the same species of the querying object ! AIOBJECTFILTER_SAMEGROUP: AI objects of the same group of the querying object or with no group ! AIOBJECTFILTER_NOGROUP :AI objects with Group ID ==AI_NOGROUP ! AIOBJECTFILTER_INCLUDEINACTIVE :Includes objects which are inactivated. |
| (optional) radius - serch range( default 30m )</param |  |

Returns: the number of found entities

docs: y · retail: confirmed (binary, runtime dump)

### GetNearestHidespot

```lua
AI.GetNearestHidespot(entityId, rangeMin, rangeMax [, center])
```

Returns position of a nearest hidepoint within specified range, returns nil if no hidepoint is found.

| Param | Description |
|---|---|
| entityId | AI's entity id |
| rangeMin | specifies the min range where the hidepoints are looked for. |
| rangeMax | specifies the max range where the hidepoints are looked for. |
| centre | (optional) specifies the centre of search. If not specified, the entity position is used. |

docs: y · retail: confirmed (binary, runtime dump)

### GetNearestPathOfTypeInRange

```lua
AI.GetNearestPathOfTypeInRange(entityId, pos, range, type [, devalue, useStartNode])
```

Queries a nearest path of specified type. The type uses same types as anchors and is specified in the path properties. ! The function will only return paths that match the requesters (entityId) navigation caps. The nav type is also ! specified in the path properties. !

| Param | Description |
|---|---|
| entityId | AI's entity id |
| pos | a vector specifying to the point of interest. Path nearest to this position is returned. |
| range | search range. If useStartNode=1, paths whose start point are within this range are returned or ! if useStartNode=0 nearest distance to the path is calculated and compared against the range. |
| type | type of path to return. |
| devalue | (optional) specifies the time the returned path is marked as occupied. |
| useStartNode | (optional) if set to 1 the range check will use distance to the start node on the path, ! else nearest distance to the path is used. |

docs: y · retail: confirmed (binary, runtime dump)

### GetNearestPointOnPath

```lua
AI.GetNearestPointOnPath(entityId, pathname, vPos)
```

returns a nearest point on the path from vPos

| Param | Description |
|---|---|
| entityId | AI's entity id |
| pathname | designers path name |
| vPos | . |

docs: y · retail: confirmed (binary, runtime dump)

### GetObjectBlackBoard

```lua
AI.GetObjectBlackBoard(entity)
```

retrieves given object's black board (a Lua table).

GetObjectBlackBoard

| Param | Description |
|---|---|
| entityId or entityName | some kind of AI entity's identifier |

Returns: black board - if there was one ! nil - Otherwise

docs: y · retail: confirmed (binary, runtime dump)

### GetObjectRadius

```lua
AI.GetObjectRadius(entityId)
```

Returns the radius of specified AI object.

| Param | Description |
|---|---|
| entityId | AI's entity id GetObjectRadius |

docs: y · retail: confirmed (binary, runtime dump)

### GetParameter

```lua
AI.GetParameter(entityId, paramEnum)
```

Changes an enumerated AI parameter.

INTEGRATION : (MATT) GetAIParameter will appear from main branch and is duplicate {2007/08/03:11:00:39} Embracing and extending their code whilst keeping the old name - wish to remain consistent with ChangeParameter above

INTEGRATION : (MATT) GetAIParameter will appear from main branch and is duplicate {2007/08/03:11:00:39} Heavily changed their code which was very limited - check their changees for new parameters

| Param | Description |
|---|---|
| entityId | entity id |
| paramEnum | index of the parameter to get, see AI.ChangeParameter() for complete list |

Returns: parameter value

docs: y · retail: confirmed (binary, runtime dump)

### GetPathSegNoOnPath

```lua
AI.GetPathSegNoOnPath(entityId, pathname, segNo)
```

returns point by segment ratio ( 0.0 start point 100.0 end point )

| Param | Description |
|---|---|
| entityId | AI's entity id |
| pathname | designer's path name |
| segNo | segment ratio |

docs: y · retail: confirmed (binary, runtime dump)

### GetPeakThreatLevel

```lua
AI.GetPeakThreatLevel(entityID)
```

C++: `int GetPeakThreatLevel (IFunctionHandler* pH , ScriptHandle entityID )`

docs: y · retail: confirmed (binary, runtime dump)

### GetPeakThreatType

```lua
AI.GetPeakThreatType(entityID)
```

C++: `int GetPeakThreatType (IFunctionHandler* pH , ScriptHandle entityID )`

docs: y · retail: confirmed (binary, runtime dump)

### GetPlayerThreatValue

```lua
AI.GetPlayerThreatValue()
```

C++: `int GetPlayerThreatLevel (IFunctionHandler * pH )`

Returns the value of player’s threat level (float number from 0 to 1.0)

docs: y · retail: unconfirmed

### GetPosturePriority

```lua
AI.GetPosturePriority(entityId, postureName)
```

C++: `int GetPosturePriority (IFunctionHandler* pH , ScriptHandle entityId , const char * postureName )`

Set the given entity's posture priority.

docs: y · retail: confirmed (binary, runtime dump)

### GetPotentialTargetCount

```lua
AI.GetPotentialTargetCount(entityID)
```

Retrieves the number of potential targets for an entity from a specified factions.

| Param | Description |
|---|---|
| entityId | id handle of entity to match against. |

docs: y · retail: confirmed (binary, runtime dump)

### GetPotentialTargetCountFromFaction

```lua
AI.GetPotentialTargetCountFromFaction(entityID, name)
```

Retrieves the number of potential targets for an entity from a specified factions.

| Param | Description |
|---|---|
| entityId | id handle of entity to match against. |
| name | name of specified faction. |

docs: y · retail: confirmed (binary, runtime dump)

### GetPredictedPosAlongPath

```lua
AI.GetPredictedPosAlongPath(entityId, time, retPos)
```

Gets the agent predicted position along his path at a given time

| Param | Description |
|---|---|
| entityId | AI's entity id |
| time | prediction time (sec) |
| retPos | return point value |

Returns: true if successful

docs: y · retail: confirmed (binary, runtime dump)

### GetPreviousBehaviorName

```lua
AI.GetPreviousBehaviorName(entityID)
```

C++: `int GetPreviousBehaviorName (IFunctionHandler* pH , ScriptHandle entityID )`

docs: y · retail: confirmed (binary, runtime dump)

### GetPreviousPeakThreatLevel

```lua
AI.GetPreviousPeakThreatLevel(entityID)
```

C++: `int GetPreviousPeakThreatLevel (IFunctionHandler* pH , ScriptHandle entityID )`

docs: y · retail: confirmed (binary, runtime dump)

### GetPreviousPeakThreatType

```lua
AI.GetPreviousPeakThreatType(entityID)
```

C++: `int GetPreviousPeakThreatType (IFunctionHandler* pH , ScriptHandle entityID )`

docs: y · retail: confirmed (binary, runtime dump)

### GetProbableTargetPosition

```lua
AI.GetProbableTargetPosition(entityId)
```

Returns the probable target position of the AI.

| Param | Description |
|---|---|
| entityId | AI's entity id GetProbableTargetPosition |

docs: y · retail: confirmed (binary, runtime dump)

### GetRangeState

```lua
AI.GetRangeState()
```

C++: `int GetRangeState (IFunctionHandler* pH , ScriptHandle entityID , int rangeID )`

This is GetRangeState, a member of class CScriptBind_AI.

docs: y · retail: unconfirmed

### GetReaction

```lua
AI.GetReaction(entityId, entity2Id | AIObjectName)
```

returns reaction of entity towards entity2 (friendly/neutral/hostile ATM)

| Param | Description |
|---|---|
| entityId | 1st AI's entity id entity2Id | AIObjectName - 2nd AI's entity id | 2nd AI object's name |

Returns: Friendly/Neutral/Hostile

docs: y · retail: unconfirmed

### GetReactionOf

```lua
AI.GetReactionOf()
```

C++: `int GetReactionOf (IFunctionHandler* pH )`

This is GetReactionOf, a member of class CScriptBind_AI.

docs: y · retail: confirmed (binary, runtime dump, vanilla×1 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/EntityCommon.lua`))

### GetRefPointDirection

```lua
AI.GetRefPointDirection(entityId)
```

Get the entity's reference point direction.

| Param | Description |
|---|---|
| entityId | AI's entity id |

Returns: (script)vector (x,y,z) reference point direction

docs: y · retail: confirmed (binary, runtime dump)

### GetRefPointPosition

```lua
AI.GetRefPointPosition(entityId)
```

Get the entity's reference point World position.

| Param | Description |
|---|---|
| entityId | AI's entity id |

Returns: (script)vector (x,y,z) reference point position

docs: y · retail: confirmed (binary, runtime dump)

### GetRefShapeName

```lua
AI.GetRefShapeName(entityId)
```

Returns the reference shape name.

| Param | Description |
|---|---|
| entityId | the ID if the entity GetRefShapeName |

docs: y · retail: confirmed (binary, runtime dump)

### GetSignalExtraData

```lua
AI.GetSignalExtraData()
```

C++: `bool GetSignalExtraData (IFunctionHandler* pH , int iParam , IAISignalExtraData*& pEData )`

This is GetSignalExtraData, a member of class CScriptBind_AI.

docs: y · retail: unconfirmed

### GetSmartObjectHelper

```lua
AI.GetSmartObjectHelper(entityId, className, helperName)
```

Returns table with position and direction vector of given SO helper

| Param | Description |
|---|---|
| entityId | entity id |
| className | SO class name |
| helperName | SO helper name |

Returns: 0 if smart object rule wasn't found or a non-zero unique id of the goal pipe inserted to execute the action

docs: y · retail: confirmed (binary, runtime dump)

### GetSoundPerceptionDescriptor

```lua
AI.GetSoundPerceptionDescriptor(entityId, soundType, descriptorTable)
```

Fills descriptorTable with info about how perception works for the entity dealing with soundType.

| Param | Description |
|---|---|
| entityId | who to get the info from |
| soundType | what type of sound stimulus to get the info for |
| descriptorTable | where to store the info once retrieved |

Returns: True if info was returned

docs: y · retail: confirmed (binary, runtime dump)

### GetStance

```lua
AI.GetStance(entityId)
```

Get the given entity's stance.

| Param | Description |
|---|---|
| entityId | AI's entity id |

Returns: entity stance (STANCE_*)

docs: y · retail: confirmed (binary, runtime dump)

### GetSubTypeOf

```lua
AI.GetSubTypeOf(entityId)
```

returns the given entity's sub type.

| Param | Description |
|---|---|
| entityId | AI's entity id |

Returns: sub type of given entity (as defined in IAgent.h).

docs: y · retail: confirmed (binary, runtime dump)

### GetTacticalPoints

```lua
AI.GetTacticalPoints(entityId, tacPointSpec, point)
```

Get a point matching a description, related to an entity. Format of a point is: { x,y,z }.

GetTacticalPoints

| Param | Description |
|---|---|
| entityId | AI's entity |
| tacPointSpec | table specifying the points required |
| point | a table put coordinates of point found |

Returns: true - If a valid point was found ! false - Otherwise

docs: y · retail: confirmed (binary, runtime dump)

### GetTargetSubType

```lua
AI.GetTargetSubType(entityId)
```

Returns the subtype of current entity's attention target.

| Param | Description |
|---|---|
| entityId | AI's entity id |

Returns: Target subtype value - see IAgent.h for all definitions of target types

docs: y · retail: confirmed (binary, runtime dump)

### GetTargetThreat

```lua
AI.GetTargetThreat(entityId)
```

Returns the threat type of current entity's attention target.

| Param | Description |
|---|---|
| entityId | AI's entity id |

Returns: Target threat type value (AITHREAT_NONE, AITHREAT_INTERESTING, AITHREAT_THREATENING, or AITHREAT_AGGRESSIVE) - see IAgent.h for all definitions of target threat types

docs: y · retail: unconfirmed

### GetTargetType

```lua
AI.GetTargetType(entityId)
```

Returns the type of current entity's attention target (memory, human, none etc).

| Param | Description |
|---|---|
| entityId | AI's entity id |

Returns: Target type value (AITARGET_NONE,AITARGET_MEMORY,AITARGET_BEACON,AITARGET_ENEMY etc) - ! see IAgent.h for all definitions of target types.

docs: y · retail: confirmed (binary, runtime dump)

### GetTotalLengthOfPath

```lua
AI.GetTotalLengthOfPath(entityId, pathname)
```

returns a total length of the path

| Param | Description |
|---|---|
| entityId | AI's entity id |
| pathname | designers path name |

docs: y · retail: confirmed (binary, runtime dump)

### GetTypeOf

```lua
AI.GetTypeOf(entityId)
```

returns the given entity's type.

| Param | Description |
|---|---|
| entityId | AI's entity id |

Returns: type of given entity (as defined in IAgent.h)

docs: y · retail: confirmed (binary, runtime dump, vanilla×4 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/AI/AISpawner.lua`))

### GetUnitCount

```lua
AI.GetUnitCount(entityId, unitProperties)
```

Gets the number of units the leader knows about. ! The leader will be found based on the group id of the entity. !

| Param | Description |
|---|---|
| entityId | AI's entity id |
| unitProperties | binary mask of the returned unit properties type ! (in the form of UPR_* + UPR* i.e. UPR_COMBAT_GROUND + UPR_COMBAT_FLIGHT) ! see IAgent.h for definition of unit properties UPR_* |

docs: y · retail: confirmed (binary, runtime dump)

### GetUnitInRank

```lua
AI.GetUnitInRank(groupID [,rank])
```

Returns the entity in the group id in the given rank position, or the highest if rank == nil or rank <=0 ! the rank is specified in entity.Properties.nRank !

| Param | Description |
|---|---|
| rank | rank position (the highest (1) if rank == nil or rank <=0) |

Returns: entity script table of the ranked unit

docs: y · retail: unconfirmed

### GoTo

```lua
AI.GoTo(entityId, vDestination)
```

This function is intended to allow AI Actor (the entity) go to the specified destination.

GoTo

| Param | Description |
|---|---|
| entityId | AI's entity |
| vDestination | . |

docs: y · retail: confirmed (binary, runtime dump, mod×1)

### Hostile

```lua
AI.Hostile(entityId, entity2Id|AIObjectName)
```

returns true if the two entities are hostile.

| Param | Description |
|---|---|
| entityId | 1st AI's entity id |
| entity2Id | AIObjectName | 2nd AI's entity id | 2nd AIobject's name |

Returns: true if the entities are hostile

docs: y · retail: confirmed (binary, runtime dump)

### IgnoreCurrentHideObject

```lua
AI.IgnoreCurrentHideObject(entityId)
```

Marks the current hideobject unreachable (will be omitted from future hidespot selections).

IgnoreCurrentHideObject

| Param | Description |
|---|---|
| entityId | AI's entity id |

docs: y · retail: confirmed (binary, runtime dump)

### InvalidateHidespot

```lua
AI.InvalidateHidespot()
```

C++: `int InvalidateHidespot (IFunctionHandler * pH )`

docs: y · retail: confirmed (binary, runtime dump)

### IsAgentInAgentFOV

```lua
AI.IsAgentInAgentFOV(entityId, entityId2)
```

Check if the entity2 is within the entity FOV.

| Param | Description |
|---|---|
| entityId | AI's entity who's FOV is checked |
| entityId2 | that's entity is looking for ;) |

Returns: 1st value - TRUE if the agent is within the entity FOV ! 2nd value - TRUE if the agent is within the entity's primary FOV or FALSE if within secondary FOV

docs: y · retail: confirmed (binary, runtime dump)

### IsAgentInTargetFOV

```lua
AI.IsAgentInTargetFOV(entityId, fov)
```

Checks if the entity is in the FOV of the attention target.

| Param | Description |
|---|---|
| entityId | AI's entity id. |
| fov | FOV of the enemy in degrees. |

Returns: true if in the FOV of the attention target else false.

docs: y · retail: confirmed (binary, runtime dump)

### IsAimReady

```lua
AI.IsAimReady(entityIdHandle)
```

C++: `int IsAimReady (IFunctionHandler* pH , ScriptHandle entityIdHandle )`

docs: y · retail: confirmed (binary, runtime dump)

### IsCoverCompromised

```lua
AI.IsCoverCompromised(entityId)
```

IsCoverCompromised

| Param | Description |
|---|---|
| entityId | AI's entity |

Returns: true - Cover is not good anymore ! nil - if not

docs: y · retail: confirmed (binary, runtime dump)

### IsEnabled

```lua
AI.IsEnabled(entityId)
```

Returns true if entity's AI is enabled.

IsEnabled

| Param | Description |
|---|---|
| entityId | entity id |

docs: y · retail: confirmed (binary, runtime dump, vanilla×9)

### IsFireEnabled

```lua
AI.IsFireEnabled(entityId)
```

Checks if AI is allowed to fire or not.

EnableFire

| Param | Description |
|---|---|
| entityId | AI's entity id |

Returns: True if AI is enabled to fire

docs: y · retail: confirmed (binary, runtime dump)

### IsFlightSpaceVoid

```lua
AI.IsFlightSpaceVoid()
```

C++: `int IsFlightSpaceVoid (IFunctionHandler * pH )`

docs: y · retail: unconfirmed

### IsFlightSpaceVoidByRadius

```lua
AI.IsFlightSpaceVoidByRadius()
```

C++: `int IsFlightSpaceVoidByRadius (IFunctionHandler * pH )`

docs: y · retail: unconfirmed

### IsGoalPipe

```lua
AI.IsGoalPipe(szPipeName)
```

Checks is a goalpipe of certain name exists already, returns true if pipe exists.

| Param | Description |
|---|---|
| szPipeName | goalpipe name |

docs: y · retail: confirmed (binary, runtime dump)

### IsInCover

```lua
AI.IsInCover(entityId)
```

C++: `int IsInCover (IFunctionHandler* pH )`

true - if AI is using cover ! nil - if not

docs: y · retail: confirmed (binary, runtime dump)

### IsLowHealthPauseActive

```lua
AI.IsLowHealthPauseActive(entityID)
```

C++: `int IsLowHealthPauseActive (IFunctionHandler* pH , ScriptHandle entityID )`

docs: y · retail: confirmed (binary, runtime dump)

### IsLowOnAmmo

```lua
AI.IsLowOnAmmo(entityId)
```

IsOutOfAmmo

| Param | Description |
|---|---|
| entityId | AI's entity |
| threshold | the ammo percentage threshold |

docs: y · retail: confirmed (binary, runtime dump)

### IsMoving

```lua
AI.IsMoving(entityId)
```

Returns true if the agent desires to move.

IsMoving

| Param | Description |
|---|---|
| entityId | AI's entity id |

docs: y · retail: confirmed (binary, runtime dump)

### IsMovingInCover

```lua
AI.IsMovingInCover(entityId)
```

IsMovingInCover

| Param | Description |
|---|---|
| entityId | AI's entity |

Returns: true - Agent is moving in cover ! nil - if not

docs: y · retail: confirmed (binary, runtime dump)

### IsMovingToCover

```lua
AI.IsMovingToCover(entityId)
```

true - Agent is running to cover ! nil - if not

IsMovingToCover

| Param | Description |
|---|---|
| entityId | AI's entity |

docs: y · retail: confirmed (binary, runtime dump)

### IsOutOfAmmo

```lua
AI.IsOutOfAmmo(entityId)
```

IsOutOfAmmo

| Param | Description |
|---|---|
| entityId | AI's entity |

Returns: true - Entity is out of ammo ! nil - if not

docs: y · retail: confirmed (binary, runtime dump)

### IsPersonallyHostile

```lua
AI.IsPersonallyHostile(entityID, hostileID)
```

C++: `int IsPersonallyHostile (IFunctionHandler* pH , ScriptHandle entityID , ScriptHandle hostileID )`

docs: y · retail: confirmed (binary, runtime dump)

### IsPointInFlightRegion

```lua
AI.IsPointInFlightRegion(start, end)
```

check if the line is in a Forbidden Region.

| Param | Description |
|---|---|
| start | a vector in format {x,y,z} |
| end | a vector in format {x,y,z} |

Returns: intersected position or end (if there is no intersection)

docs: y · retail: confirmed (binary, runtime dump)

### IsPointInsideGenericShape

```lua
AI.IsPointInsideGenericShape(position, shapeName[, checkHeight])
```

Returns true if the point is inside the specified shape.

| Param | Description |
|---|---|
| position | the position to check |
| shapeName | the name of the shape to test (returned by AI.GetEnclosingGenericShapeOfType) |
| checkHeight | (optional) Default=false, if the flag is set the height of the shape is tested too. The test will check space between the shape.aabb.min.z and shape.aabb.min.z+shape.height. IsPointInsideGenericShape |

docs: y · retail: confirmed (binary, runtime dump)

### IsPunchableObjectValid

```lua
AI.IsPunchableObjectValid(userId, objectId, origPos)
```

Checks if a punchable object is valid.

| Param | Description |
|---|---|
| userId | User ID. |
| objectId | Object ID. |
| origPos | Object position in the world. |

docs: y · retail: confirmed (binary, runtime dump)

### IsTakingCover

```lua
AI.IsTakingCover(entityId, [distanceThreshold])
```

IsTakingCover

| Param | Description |
|---|---|
| entityId | AI's entity |
| distanceThreshold | (optional) distance over which if the agent is running to cover, he won't be considered as taking cover |

Returns: true - Agent is either in cover or running to cover ! nil - if not

docs: y · retail: confirmed (binary, runtime dump)

### LoadBehaviors

```lua
AI.LoadBehaviors(folderName, extension, globalEnv)
```

C++: `int LoadBehaviors (IFunctionHandler * pH , const char * folderName , const char * extension )`

docs: y · retail: confirmed (binary, runtime dump)

### LoadCharacters

```lua
AI.LoadCharacters(folderName, tbl)
```

C++: `int LoadCharacters (IFunctionHandler * pH , const char * folderName , SmartScriptTable tbl )`

docs: y · retail: unconfirmed

### LoadGoalPipes

```lua
AI.LoadGoalPipes()
```

C++: `int LoadGoalPipes (IFunctionHandler* pH )`

XML support for goal pipes ///////////////////////////////////////////////////////////////////////////////////////////////////////

docs: y · retail: confirmed (binary, runtime dump)

### LoadGroupBehaviors

```lua
AI.LoadGroupBehaviors(folderName, extension, globalEnv)
```

C++: `int LoadGroupBehaviors (IFunctionHandler * pH , const char * folderName , const char * extension )`

docs: y · retail: unconfirmed

### LoadPathfindProperties

```lua
AI.LoadPathfindProperties()
```

C++: `int LoadPathfindProperties (IFunctionHandler* pH )`

This is LoadPathfindProperties, a member of class CScriptBind_AI.

docs: y · retail: unconfirmed

### LockBodyTurn

```lua
AI.LockBodyTurn(entityID, bAllowLowerBodyToTurn)
```

| Param | Description |
|---|---|
| bool bAllowLowerBodyToTurn | true if you want to allow the turning movement of the body, false otherwise |
| entityId | entity id of the agent you want to set the look style to |

docs: y · retail: unconfirmed

### LogComment

```lua
AI.LogComment(szMessage)
```

Used to indicate info that would be useful for debugging, ! but there's too much of it for it to be enabled all the time.

LogComment

| Param | Description |
|---|---|
| szMessage | message line to be displayed in log |

docs: y · retail: confirmed (binary, runtime dump, vanilla×2 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/AI/SmartObject.lua`))

### LogEvent

```lua
AI.LogEvent(szMessage)
```

Used to indicate event-driven info that would be useful for debugging ! (may occur on a per-frame or even per-AI-update basis). !

LogEvent

| Param | Description |
|---|---|
| szMessage | message line to be displayed in log |

docs: y · retail: confirmed (binary, runtime dump, vanilla×10 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/AI/AISpawner.lua`))

### LogProgress

```lua
AI.LogProgress(szMessage)
```

Used to indicate "progress markers"">e.g. during loading.

LogProgress

| Param | Description |
|---|---|
| szMessage | message line to be displayed in log |

docs: y · retail: confirmed (binary, runtime dump)

### MeleePunchableObject

```lua
AI.MeleePunchableObject(entityId, objectId, origPos)
```

| Param | Description |
|---|---|
| entityId | AI's entity ID. |
| objectId | Object ID. |
| origPos | Position of the melee punchable object |

docs: y · retail: confirmed (binary, runtime dump)

### ModifySmartObjectStates

```lua
AI.ModifySmartObjectStates(entityId, listStates)
```

Adds/Removes smart object states of a given entity.

| Param | Description |
|---|---|
| entityId | entity id |
| listStates | names of the states to be added and removed (i.e. "Closed, Locked">Open, Unlocked, Busy") |

docs: y · retail: confirmed (binary, runtime dump)

### Neutral

```lua
AI.Neutral(entityId, entity2Id|AIObjectName)
```

returns true if the two entities are neutral

| Param | Description |
|---|---|
| entityId | 1st AI's entity id entity2Id |AIObjectName - 2nd AI's entity id | 2nd AIobject's name |

Returns: true if the entities are neutral

docs: y · retail: unconfirmed

### NotifyGroup

```lua
AI.NotifyGroup()
```

C++: `int NotifyGroup (IFunctionHandler* pH , int groupID , ScriptHandle sender , const char * notification )`

This is NotifyGroup, a member of class CScriptBindAI.

docs: y · retail: confirmed (binary, runtime dump)

### NotifyReinfDone

```lua
AI.NotifyReinfDone()
```

C++: `int NotifyReinfDone (IFunctionHandler * pH )`

docs: y · retail: confirmed (binary, runtime dump)

### NotifySurpriseEntityAction

```lua
AI.NotifySurpriseEntityAction()
```

C++: `int NotifySurpriseEntityAction (IFunctionHandler * pH )`

NotifySurpriseEntityAction

docs: y · retail: confirmed (binary, runtime dump)

### ParseTables

```lua
AI.ParseTables(firstTable,parseMovementAbility,pH,aiParams,updateAlways)
```

| Param | Description |
|---|---|
| int firstTable | Properties table. |
| bool parseMovementAbility | True to parse movement ability, false otherwise. |
| AIObjectParams& aiParams | AI parameters. |
| bool& updateAlways | . |

docs: y · retail: unconfirmed

### PlayCommunication

```lua
AI.PlayCommunication(entityId, commName, channelName[, targetId] [, targetPos])
```

Plays communication on the AI agent.

Syntax: AI.PlayCommunication(entityId, commName, channelName[, targetId] [, targetPos])

Plays communication on the AI agent.

| Param | Description |
|---|---|
| ScriptHandle entityId | AI's entity id AI's entity id |
| const char* commName | The name of the communication to play The name of the communication to play |
| const char* channelName | The name of the channel where the communication will play The name of the channel where the communication will play |

docs: y · retail: confirmed (binary, runtime dump)

### PlayReadabilitySound

```lua
AI.PlayReadabilitySound(entityId, soundName)
```

Plays readability sound on the AI agent. This call does not do any filtering like playing readability using signals.

| Param | Description |
|---|---|
| entityId | AI's entity id |
| soundName | the name of the readability sound signal to play |
| stopPreviousSounds *(optional)* | TRUE if any currently playing readability should be stopped in favor of this one |
| responseDelayMin *(optional)* | Minimum (or exact, if no maximum) delay for the Response readability to play |
| repsonseDelayMax *(optional)* | Maximum delay for the Response readability to play |

docs: y · retail: unconfirmed

### ProcessBalancedDamage

```lua
AI.ProcessBalancedDamage(pShooterEntity, pTargetEntity, damage, damageType)
```

Processes balanced damage.

| Param | Description |
|---|---|
| pShooterEntity | Shooter ID. |
| pTargetEntity | Target ID. |
| damage | Hit damage. |
| damageType | Hit damage type. |

docs: y · retail: confirmed (binary, runtime dump)

### PushGoal

```lua
AI.PushGoal(szPipeName, goalName, blocking [,{params}])
```

Used for warnings about data/script errors.

Push a goal into a goal pipe. The goal is appended at the end of the goal pipe. Pipe of given name has to be previously created. @param name of the goal pipe in which the goal will be pushed. @param name of atomic goal that needs to be pushed into the pipe @param 1 if the goal should block the pipe execution, 0 if the goal should not block the goal execution @see CScriptBind_AI::CreateGoalPipe

| Param | Description |
|---|---|
| szPipeName | goal pipe name |
| szGoalName | goal name - see AI Manual for a complete list of goals |
| blocking | used to mark the goal as blocking (goal pipe execution will stop here |
| until the goal has finished) 0: not blocking, 1: blocking</param |  |
| (optional) params | set of parameters depending on the goal selected; see the AI Manual for a complete list of the parameters for each goal |

docs: y · retail: confirmed (binary, runtime dump)

### PushLabel

```lua
AI.PushLabel(szPipeName, szLabelName)
```

Used in combination with "branch" goal operation to identify jump destination.

Push a label into a goal pipe. The label is appended at the end of the goal pipe. Pipe of given name has to be previously created. @param name of the goal pipe in which the goal will be pushed. @param name of the label that needs to be pushed into the pipe @see CScriptBind_AI::CreateGoalPipe

| Param | Description |
|---|---|
| szPipeName | goalpipe name |
| szLabelName | label name |

docs: y · retail: confirmed (binary, runtime dump)

### QueueBubbleMessage

```lua
AI.QueueBubbleMessage(entityID, message, flags)
```

C++: `int QueueBubbleMessage (IFunctionHandler* pH , ScriptHandle entityID , const char * message )`

docs: y · retail: confirmed (binary, runtime dump)

### RayWorldIntersectionWrapper

```lua
AI.RayWorldIntersectionWrapper()
```

C++: `int RayWorldIntersectionWrapper (Vec3 org , Vec3 dir , int objtypes , unsigned int flags , ray_hit * hits , int nMaxHits , IPhysicalEntity ** pSkipEnts = 0, int nSkipEnts = 0, void * pForeignData = 0, int iForeignData = 0)`

wrapper, to make it use tick-counter

docs: y · retail: unconfirmed

### RecComment

```lua
AI.RecComment(szMessage)
```

Record comment with AIRecorder.

RecComment

| Param | Description |
|---|---|
| szMessage | message line to be displayed in recorder view |

docs: y · retail: confirmed (binary, runtime dump)

### RegisterDamageRegion

```lua
AI.RegisterDamageRegion(entityId, radius)
```

Register a spherical region that causes damage (so should be avoided in pathfinding). ! Owner entity position is used as region center. Can be called multiple times, will just move ! update region position !

RegisterDamageRegion

| Param | Description |
|---|---|
| entityId | owner entity id. |
| radius | If radius <= 0 then the region is disabled |

docs: y · retail: confirmed (binary, runtime dump, mod×3)

### RegisterInterestedActor

```lua
AI.RegisterInterestedActor(entityId, fInterestFilter, fAngleInDegrees)
```

Registers the interested actor with the interest system. Any errors go to the error log.

| Param | Description |
|---|---|
| ScriptHandle entityId | AI's entity |

Returns: true - if a valid update was performed ! nil - if not (Interest system is disabled, parameters not valid, etc)

docs: y · retail: confirmed (binary, runtime dump)

### RegisterInterestingEntity

```lua
AI.RegisterInterestingEntity(entityId, baseInterest, category, aiAction)
```

Registers the entity with the interest system. Any errors go to the error log.

| Param | Description |
|---|---|
| ScriptHandle entityId | AI's entity id |

Returns: true - if a valid update was performed ! nil - if not (Interest system is disabled, parameters not valid, etc)

docs: y · retail: confirmed (binary, runtime dump)

### RegisterTacticalPointQuery

```lua
AI.RegisterTacticalPointQuery(querySpecTable)
```

Get a query ID for the given tactical point query.

RegisterTacticalPointQuery

| Param | Description |
|---|---|
| querySpecTable | table specifying the query (a mini-language - see Tactical Point System docs elsewhere) |

Returns: > 0 - If the query was parsed successfully ! 0 - Otherwise

docs: y · retail: confirmed (binary, runtime dump)

### RegisterTargetTrack

```lua
AI.RegisterTargetTrack(entityId, configuration, targetLimit, classThreat)
```

Registers the AI object to use the given target track configuration for target selection.

| Param | Description |
|---|---|
| entityId | AI's entity id |
| configuration | Target stimulus configuration to use |
| targetLimit | Number of agents who can target the AI at any given time (0 for infinite) |
| classThreat | (Optional) Initial class threat value for the user |

Returns: True if registration was successful. Note that this does nothing if 'ai_TargetTracking' is not set to '2'

docs: y · retail: confirmed (binary, runtime dump)

### Release

```lua
AI.Release()
```

C++: `void Release ()`

This is Release, a member of class CScriptBind_AI.

docs: y · retail: unconfirmed

### RemoveCoverEntity

```lua
AI.RemoveCoverEntity()
```

C++: `int RemoveCoverEntity (IFunctionHandler* pH , ScriptHandle entityID )`

This is RemoveCoverEntity, a member of class CScriptBind_AI.

docs: y · retail: confirmed (binary, runtime dump)

### RemovePersonallyHostile

```lua
AI.RemovePersonallyHostile(entityID, hostileID)
```

C++: `int RemovePersonallyHostile (IFunctionHandler* pH , ScriptHandle entityID , ScriptHandle hostileID )`

docs: y · retail: confirmed (binary, runtime dump)

### RequestAttack

```lua
AI.RequestAttack(entityId, unitProperties, attackTypeList [,duration])
```

in a group with leader, the entity requests for a group attack behavior against the enemy ! The Cleader later will possibly create an attack leader action (CLeaderAction_Attack_*) !

| Param | Description |
|---|---|
| entityId | AI's entity id which group/leader is determined |
| unitProperties | binary mask of unit properties type for which the attack is requested ! (in the form of UPR_* + UPR* i.e. UPR_COMBAT_GROUND + UPR_COMBAT_FLIGHT) ! see IAgent.h for definition of unit properties UPR_* |
| attackTypeList | a lua table which contains the list of preferred attack strategies (Leader action subtypes), ! sorted by priority (most preferred first) ! the list must be in the format {LAS_*, LAS_*,..} i.e. (LAS_ATTACK_ROW,LAS_ATTACK_FLANK} means that first an Attack_row ! action will be tried, then an attack_flank if the first ends/fails. ! see IAgent.h for definition of LeaderActionSubtype (LAS_*) action types |
| duration | (optional) max duration in sec (default = 0) |

docs: y · retail: unconfirmed

### RequestToStopMovement

```lua
AI.RequestToStopMovement(entityId)
```

C++: `int RequestToStopMovement (IFunctionHandler* pH , ScriptHandle entityId )`

docs: y · retail: confirmed (binary, runtime dump)

### ResetAgentLookAtPos

```lua
AI.ResetAgentLookAtPos(entityId)
```

Makes the entityId resets a previous call to AgentLookAtPos().

| Param | Description |
|---|---|
| entityId | AI's entity id. |

docs: y · retail: confirmed (binary, runtime dump)

### ResetAgentState

```lua
AI.ResetAgentState(entityId,stateLabel)
```

Resets a particular aspect of the agent's state, such as "lean". Intended to keep these hacky concepts together.

ResetAgentState

| Param | Description |
|---|---|
| ScriptHandle entityId | AI's entity |
| const char* stateLabel | string describing the state that must be reset to default |

Returns: nil

docs: y · retail: confirmed (binary, runtime dump)

### ResetMovementContext

```lua
AI.ResetMovementContext(entityId)
```

Reset the given entity's movement context.

| Param | Description |
|---|---|
| ScriptHandle entityId | AI's entity id |
| int context | context value |

docs: y · retail: unconfirmed

### ResetParameters

```lua
AI.ResetParameters(entityId, bProcessMovement, PropertiesTable, PropertiesInstanceTable)
```

Resets all the AI parameters.

| Param | Description |
|---|---|
| entityId | entity id |
| bProcessMovement | reset movement data as well |
| PropertiesTable | Lua table containing the entity properties like groupid, sightrange, sound range etc (editable in editor, usually defined as "Properties") |
| PropertiesInstanceTable | another properties table, same as PropertiesTable (editable in editor, usually defined as "PropertiesInstance") |

docs: y · retail: confirmed (binary, runtime dump, vanilla×2 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/actor/player.lua`))

### ResetPersonallyHostiles

```lua
AI.ResetPersonallyHostiles(entityID, hostileID)
```

C++: `int ResetPersonallyHostiles (IFunctionHandler* pH , ScriptHandle entityID , ScriptHandle hostileID )`

docs: y · retail: confirmed (binary, runtime dump)

### ResetRanges

```lua
AI.ResetRanges()
```

C++: `int ResetRanges (IFunctionHandler* pH , ScriptHandle entityID )`

This is ResetRanges, a member of class CScriptBind_AI.

docs: y · retail: unconfirmed

### RunStartupScript

```lua
AI.RunStartupScript()
```

C++: `void RunStartupScript ()`

RunStartupScript

docs: y · retail: unconfirmed

### ScaleFormation

```lua
AI.ScaleFormation(entityId, scale)
```

changes the scale factor of the given entity's formation (if there is).

| Param | Description |
|---|---|
| entityId | entity id of which group the formation is scaled |
| scale | scale factor |

Returns: true if the formation scaling was successful

docs: y · retail: confirmed (binary, runtime dump)

### SendBTGlobalSignal

```lua
AI.SendBTGlobalSignal(signal, data)
```

Send a signal to the BT global activation conditions

| Param | Description |
|---|---|
| signal | Signal to send |
| data | Signal extra data |

docs: y · retail: unconfirmed

### SequenceBehaviorReady

```lua
AI.SequenceBehaviorReady(entityId)
```

C++: `int SequenceBehaviorReady (IFunctionHandler* pH , ScriptHandle entityId )`

docs: y · retail: confirmed (binary, runtime dump)

### SequenceInterruptibleBehaviorLeft

```lua
AI.SequenceInterruptibleBehaviorLeft(entityId)
```

C++: `int SequenceInterruptibleBehaviorLeft (IFunctionHandler* pH , ScriptHandle entityId )`

docs: y · retail: confirmed (binary, runtime dump)

### SequenceNonInterruptibleBehaviorLeft

```lua
AI.SequenceNonInterruptibleBehaviorLeft(entityId)
```

C++: `int SequenceNonInterruptibleBehaviorLeft (IFunctionHandler* pH , ScriptHandle entityId )`

docs: y · retail: confirmed (binary, runtime dump)

### SetAdjustPath

```lua
AI.SetAdjustPath()
```

C++: `int SetAdjustPath (IFunctionHandler * pH )`

docs: y · retail: confirmed (binary, runtime dump, mod×1)

### SetAlarmed

```lua
AI.SetAlarmed(entityId)
```

C++: `int SetAlarmed (IFunctionHandler* pH )`

This function sets the entity to be "perception alarmed".

docs: y · retail: confirmed (binary, runtime dump)

### SetAnimationTag

```lua
AI.SetAnimationTag(entityId, tagName)
```

Set a Mannequin animation tag.

In: The function handler (NULL is invalid!) In: The script handle of the entity on which to set the animation tag. In: The name of the animation tag that should be set (case insensitive).

| Param | Description |
|---|---|
| const char* tagName | . |
| entityId | AI's entity |

Returns: A default result code (in Lua: void).

docs: y · retail: confirmed (binary, runtime dump)

### SetAssesmentMultiplier

```lua
AI.SetAssesmentMultiplier(AIObjectType, multiplier)
```

set the assesment multiplier factor for the given AIObject type.

| Param | Description |
|---|---|
| AIObjectType | AIObject type; see ScriptBindAI.cpp for a complete list of AIObject types available |
| multiplier | assesment multiplication factor |

docs: y · retail: confirmed (binary, runtime dump)

### SetAttentiontarget

```lua
AI.SetAttentiontarget(entityId, targetId)
```

Set a new attention target.

SetAttentiontarget

| Param | Description |
|---|---|
| entityId | AI's entity |
| targetId | target's id |

docs: y · retail: confirmed (binary, runtime dump)

### SetBeaconPosition

```lua
AI.SetBeaconPosition(entityId | AIObjectName, pos)
```

Set the beacon's position for the given entity/object's group.

| Param | Description |
|---|---|
| entityId | AIObjectName | AI's entity id | AI object name |
| pos | beacon position vector {x,y,z} |

docs: y · retail: confirmed (binary, runtime dump)

### SetBehaviorTreeEvaluationEnabled

```lua
AI.SetBehaviorTreeEvaluationEnabled(entityID, enable)
```

C++: `int SetBehaviorTreeEvaluationEnabled (IFunctionHandler* pH , ScriptHandle entityID , bool enable )`

docs: y · retail: confirmed (binary, runtime dump)

### SetBehaviorVariable

```lua
AI.SetBehaviorVariable(entity, variableName, value)
```

C++: `int SetBehaviorVariable (IFunctionHandler* pH , ScriptHandle entityId , const char * variableName , bool value )`

Sets a behaviour variable for the specified actor.

docs: y · retail: confirmed (binary, runtime dump)

### SetCharacter

```lua
AI.SetCharacter(entityId, newCharater)
```

Sets the AI character of the entity.

| Param | Description |
|---|---|
| entityId | AI's entity id |
| newCharacter | name of the new character to set. |

docs: y · retail: unconfirmed

### SetCollisionAvoidanceRadiusIncrement

```lua
AI.SetCollisionAvoidanceRadiusIncrement(entityId, radius)
```

C++: `int SetCollisionAvoidanceRadiusIncrement (IFunctionHandler* pH , ScriptHandle entityId , float radius )`

docs: y · retail: confirmed (binary, runtime dump, mod×3)

### SetContinuousMotion

```lua
AI.SetContinuousMotion(entityID, continuousMotion)
```

C++: `int SetContinuousMotion (IFunctionHandler* pH , ScriptHandle entityID , bool continuousMotion )`

docs: y · retail: confirmed (binary, runtime dump)

### SetCoordinationInput

```lua
AI.SetCoordinationInput(coordinationID, name, value)
```

C++: `int SetCoordinationInput (IFunctionHandler* pH , ScriptHandle coordinationID , const char * name )`

docs: y · retail: unconfirmed

### SetCoverCompromised

```lua
AI.SetCoverCompromised(entityId)
```

| Param | Description |
|---|---|
| entityId | AI's entity |

docs: y · retail: confirmed (binary, runtime dump)

### SetEntitySpeedRange

```lua
AI.SetEntitySpeedRange(userEntityId, urgency, defaultSpeed, minSpeed, maxSpeed, stance = all)
```

This function allows the user to override the entity's speed range for the given urgency.

SetEntitySpeedRange

| Param | Description |
|---|---|
| usedEntityId | entity id of the user for which its last used smart object is needed |
| urgency | integer value specifying the movement urgency (see AgentMovementSpeeds::EAgentMovementUrgency) |
| defaultSpeed | floating point value specifying the default speed |
| minSpeed | floating point value specifying the min speed |
| maxSpeedfloating point value specifying the max speed</param |  |
| stance | optional parameter specifying the stance for which the range is set. default is all (see AgentMovementSpeeds::EAgentMovementStance) |

Returns: true if the operation was successful and false otherwise

docs: y · retail: confirmed (binary, runtime dump)

### SetEntityTacticGroupId

```lua
AI.SetEntityTacticGroupId(entity, groupId)
```

Sets which tactic group Id an entity belongs to

| Param | Description |
|---|---|
| groupId | The Tactic group Id to be assigned |

docs: y · retail: unconfirmed

### SetExtraPriority

```lua
AI.SetExtraPriority(enemyEntityId, increment)
```

Set a extra priority value to the entity which is given by enemyEntityId.

| Param | Description |
|---|---|
| enemyEntityId | AI's entity id |
| float increment | value to add to the target's priority |

docs: y · retail: confirmed (binary, runtime dump)

### SetFactionOf

```lua
AI.SetFactionOf(entityID, factionName)
```

C++: `int SetFactionOf (IFunctionHandler* pH , ScriptHandle entityID , const char * factionName )`

Make the specified entity a member of the named faction.

docs: y · retail: confirmed (binary, runtime dump)

### SetFactionThreatMultiplier

```lua
AI.SetFactionThreatMultiplier(nSpecies, multiplier)
```

set the threat multiplier factor for the given species (if 0, species is not hostile to any other).

| Param | Description |
|---|---|
| factionID | factionID</param |
| multiplier | Threat multiplication factor |

docs: y · retail: confirmed (binary, runtime dump)

### SetFireMode

```lua
AI.SetFireMode(entityId, mode)
```

Immediately sets firemode.

| Param | Description |
|---|---|
| entityId | AI's entity id |
| firemode | new firemode |

docs: y · retail: confirmed (binary, runtime dump)

### SetForcedNavigation

```lua
AI.SetForcedNavigation()
```

C++: `int SetForcedNavigation (IFunctionHandler * pH )`

docs: y · retail: confirmed (binary, runtime dump, mod×3)

### SetForcedNavigationCompVec

```lua
AI.SetForcedNavigationCompVec()
```

C++: `int SetForcedNavigationCompVec (IFunctionHandler * pH )`

docs: y · retail: unconfirmed

### SetFormationAngleThreshold

```lua
AI.SetFormationAngleThreshold(entityId, fAngleThreshold)
```

Sets the Relative position inside the formation.

AI.SetFormationAngleThreshold(entityId, fAngleThreshold )

| Param | Description |
|---|---|
| entityId | AI's entity |
| fAngleThreshold | New Leader orientation angle threshold in degrees to recal position |

docs: y · retail: confirmed (binary, runtime dump)

### SetFormationLookingPoint

```lua
AI.SetFormationLookingPoint(entityId, v3RelativePosition)
```

Sets the Relative looking point position inside the formation.

AI.SetFormationLookingPoint(entityId, v3RelativePosition )

| Param | Description |
|---|---|
| entityId | AI's entity |
| v3RelativePosition | Table with format {x,y,z} storing the new relative looking point |

docs: y · retail: confirmed (binary, runtime dump)

### SetFormationPosition

```lua
AI.SetFormationPosition(entityId, v2RelativePosition)
```

Sets the Relative position inside the formation.

AI.SetFormationPosition(entityId, v2RelativePosition )

| Param | Description |
|---|---|
| entityId | AI's entity |
| v2RelativePosition | Table with format {x,y} storing the new relative position |

docs: y · retail: confirmed (binary, runtime dump)

### SetFormationUpdate

```lua
AI.SetFormationUpdate(entityId, update)
```

Changes the update flag of the given entity's formation (if there is) - ! the formation is no more updated if the flag is false. !

| Param | Description |
|---|---|
| entityId | entity id of which group the formation is scaled |
| update | update flag (true/false) |

Returns: true if the formation update setting was successful

docs: y · retail: confirmed (binary, runtime dump)

### SetFormationUpdateSight

```lua
AI.SetFormationUpdateSight(entityId, range, minTime, maxTime)
```

Sets a random angle rotation for the given entity's formation sight directions.

| Param | Description |
|---|---|
| entityId | entity id owner of the formation |
| range | angle (0,360) of rotation around the default sight direction |
| minTime *(optional)* | minimum timespan for changing the direction (default = 2) |
| maxTime *(optional)* | minimum timespan for changing the direction (default = minTime) |

docs: y · retail: confirmed (binary, runtime dump)

### SetIgnorant

```lua
AI.SetIgnorant(entityId, ignorant)
```

makes an AI ignore system signals, visual stimuli and sound stimuli.

| Param | Description |
|---|---|
| entityId | AI's entity id |
| ignorant | 0: not ignorant, 1: ignorant |

docs: y · retail: confirmed (binary, runtime dump)

### SetInCover

```lua
AI.SetInCover(entityId, inCover)
```

| Param | Description |
|---|---|
| entityId | AI's entity |
| inCover | if the AI should be set to be in cover or not |

docs: y · retail: confirmed (binary, runtime dump)

### SetLastOpResult

```lua
AI.SetLastOpResult()
```

C++: `int SetLastOpResult (IFunctionHandler* pH , ScriptHandle entityIdHandle , ScriptHandle targetEntityIdHandle )`

This is SetLastOpResult, a member of class CScriptBind_AI.

docs: y · retail: confirmed (binary, runtime dump)

### SetLeader

```lua
AI.SetLeader(entityID)
```

Set the given entity as Leader (associating a CLeader object to it and creating it if it doesn't exist) ! Only one leader can be set per group. !

Makes an entity a leader of the group @return 1 if succeeded

| Param | Description |
|---|---|
| entityID | entity (id) of which to which we want to associate a leader class |

Returns: true if the leader creation/association has been successful

docs: y · retail: confirmed (binary, runtime dump, vanilla×1 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/actor/player.lua`))

### SetMemoryFireType

```lua
AI.SetMemoryFireType(entityId, type)
```

Sets how the puppet handles firing at its memory target.

| Param | Description |
|---|---|
| entityId | AI's entity id |
| type | Memory fire type (see EMemoryFireType) |

docs: y · retail: confirmed (binary, runtime dump)

### SetMovementContext

```lua
AI.SetMovementContext(entityId, context)
```

Set the given entity's movement context.

| Param | Description |
|---|---|
| ScriptHandle entityId | AI's entity id |
| int context | context value |

docs: y · retail: confirmed (binary, runtime dump)

### SetPathAttributeToFollow

```lua
AI.SetPathAttributeToFollow(entityId, flag)
```

Set the attribute of the path to be used in 'followpath' goal operation.

| Param | Description |
|---|---|
| entityId | AI's entity id |
| flag | . |

docs: y · retail: confirmed (binary, runtime dump)

### SetPathToFollow

```lua
AI.SetPathToFollow(entityId, pathName)
```

Set the name of the path to be used in 'followpath' goal operation.

| Param | Description |
|---|---|
| entityId | AI's entity id |
| pathName | (string) name of the path to set to be followed. |

docs: y · retail: confirmed (binary, runtime dump)

### SetPFBlockerRadius

```lua
AI.SetPFBlockerRadius(entityId, blocker, radius)
```

| Param | Description |
|---|---|
| entityId | AI's entity id |

docs: y · retail: confirmed (binary, runtime dump, mod×3)

### SetPointListToFollow

```lua
AI.SetPointListToFollow(entityId, pointlist, howmanypoints, bspline [, navtype])
```

Set a point list for followpath goal op

| Param | Description |
|---|---|
| entityId | AI's entity id |
| pointList | should be like below local vectors = { { x = 0.0, y = 0.0, z = 0.0 }, -- vectors[1].(x,y,z) { x = 0.0, y = 0.0, z = 0.0 }, -- vectors[2].(x,y,z) { x = 0.0, y = 0.0, z = 0.0 }, -- vectors[3].(x,y,z) { x = 0.0, y = 0.0, z = 0.0 }, -- vectors[4].(x,y,z) { x = 0.0, y = 0.0, z = 0.0 }, -- vectors[5].(x,y,z) { x = 0.0, y = 0.0, z = 0.0 }, -- vectors[6].(x,y,z) { x = 0.0, y = 0.0, z = 0.0 }, -- vectors[7].(x,y,z) { x = 0.0, y = 0.0, z = 0.0 }, -- vectors[8].(x,y,z) } |
| howmanypoints | . |
| bspline | if true, the line is recalcurated by spline interpolation. |
| navtype | (optional) specify a navigation type ( default = IAISystem::NAV_FLIGHT ) |

docs: y · retail: confirmed (binary, runtime dump, mod×1)

### SetPosturePriority

```lua
AI.SetPosturePriority(entityId, postureName, priority)
```

C++: `int SetPosturePriority (IFunctionHandler* pH , ScriptHandle entityId , const char * postureName , float priority )`

Set the given entity's posture priority.

docs: y · retail: confirmed (binary, runtime dump)

### SetPostures

```lua
AI.SetPostures(entityId, postures)
```

Set the given entity's postures.

| Param | Description |
|---|---|
| ScriptHandle entityId | AI's entity id |
| SmartScriptTable postures | . |

docs: y · retail: confirmed (binary, runtime dump)

### SetReactionOf

```lua
AI.SetReactionOf()
```

C++: `int SetReactionOf (IFunctionHandler* pH , const char * factionOne , const char * factionTwo , int reaction )`

This is SetReactionOf, a member of class CScriptBind_AI.

docs: y · retail: confirmed (runtime dump)

### SetRefPointAtDefensePos

```lua
AI.SetRefPointAtDefensePos(entityId, point2defend, distance)
```

Set the entity refpoint position in an intermediate distance between the entity's att target and the given point.

| Param | Description |
|---|---|
| entityId | AI's entity id |
| point2defend | point to defend |
| distance | max distance to keep from the point |

docs: y · retail: confirmed (binary, runtime dump)

### SetRefPointDirection

```lua
AI.SetRefPointDirection(vRefPointDir)
```

Sets the reference point's World position of an entity

| Param | Description |
|---|---|
| vRefPointDir | (script)vector (x,y,z) value |

docs: y · retail: confirmed (binary, runtime dump)

### SetRefPointPosition

```lua
AI.SetRefPointPosition(entityId, vRefPointPos)
```

Sets the reference point's World position of an entity

| Param | Description |
|---|---|
| entityId | entity id |
| vRefPointPos | (script)vector (x,y,z) value |

docs: y · retail: confirmed (binary, runtime dump)

### SetRefPointRadius

```lua
AI.SetRefPointRadius(entityId, radius)
```

Sets the reference point's radius.

| Param | Description |
|---|---|
| entityId | the entity id of the AI. |
| radius | the radius to set. |

docs: y · retail: confirmed (binary, runtime dump)

### SetRefpointToAnchor

```lua
AI.SetRefpointToAnchor(entityId, rangeMin, rangeMax, findType, findMethod)
```

Sets a reference point to an anchor.

| Param | Description |
|---|---|
| entityId | AI's entity ID. |
| rangeMin | Minimum range. |
| rangeMax | Maximum range. |
| findType | Finding type. |
| findMethod | Finding method. |

docs: y · retail: confirmed (binary, runtime dump)

### SetRefPointToGrenadeAvoidTarget

```lua
AI.SetRefPointToGrenadeAvoidTarget()
```

C++: `int SetRefPointToGrenadeAvoidTarget (IFunctionHandler * pH )`

docs: y · retail: confirmed (binary, runtime dump)

### SetRefpointToPunchableObject

```lua
AI.SetRefpointToPunchableObject(entityId, range)
```

Sets the reference point to the punchable object.

| Param | Description |
|---|---|
| entityId | AI's entity ID. |
| range | Range for the punchable object. |

docs: y · retail: confirmed (binary, runtime dump)

### SetRefShapeName

```lua
AI.SetRefShapeName(entityId, name)
```

Sets the reference shape name.

SetRefShapeName

| Param | Description |
|---|---|
| entityId | AI's entity id |
| name | the name of the reference shape. |

docs: y · retail: confirmed (binary, runtime dump)

### SetSmartObjectState

```lua
AI.SetSmartObjectState(entityId, stateName)
```

Sets only one single smart object state replacing all other states.

| Param | Description |
|---|---|
| entityId | entity id |
| stateName | name of the new state (i.e. "Idle") |

docs: y · retail: confirmed (binary, runtime dump)

### SetSoundPerceptionDescriptor

```lua
AI.SetSoundPerceptionDescriptor(entityId, soundType, descriptorTable)
```

Sets data on how perception works for the entity dealing with soundType.

| Param | Description |
|---|---|
| entityId | who to set the info for |
| soundType | what type of sound stimulus to set the info for |
| descriptorTable | info to be set |

Returns: True if info was saved

docs: y · retail: confirmed (binary, runtime dump)

### SetSpeed

```lua
AI.SetSpeed(entityId, urgency)
```

This function allows the user to override the entity's current speed (urgency).

SetSpeed

| Param | Description |
|---|---|
| entityId | AI's entity |
| urgency | float value specifying the movement urgency (see AgentMovementSpeeds::EAgentMovementUrgency) |

docs: y · retail: confirmed (binary, runtime dump)

### SetStance

```lua
AI.SetStance(entityId, stance)
```

Set the given entity's stance.

| Param | Description |
|---|---|
| entityId | AI's entity id |
| stance | stance value (STANCE_*) |

docs: y · retail: confirmed (binary, runtime dump, vanilla×1 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/AI/Shared/BasicAI.lua`))

### SetTargetTrackClassThreat

```lua
AI.SetTargetTrackClassThreat(entityId, classThreat)
```

Sets the class threat for the entity for target track usage.

| Param | Description |
|---|---|
| entityId | AI's entity id |
| classThreat | Class threat value for the user |

docs: y · retail: confirmed (binary, runtime dump)

### SetTempTargetPriority

```lua
AI.SetTempTargetPriority(entityId, priority)
```

Set the selection priority of the temp target over other potential targets.

| Param | Description |
|---|---|
| entityId | AI's entity id |
| priority | New priority value |

Returns: true if updated

docs: y · retail: confirmed (binary, runtime dump)

### SetTerritoryShapeName

```lua
AI.SetTerritoryShapeName(entityId, shapeName)
```

Sets the territory of the AI Actor.

SetTerritoryShapeName

| Param | Description |
|---|---|
| entityId | AI's entity id |
| shapeName | name of the shape to set |

docs: y · retail: confirmed (binary, runtime dump)

### SetUnitProperties

```lua
AI.SetUnitProperties(entityId, unitProperties)
```

Sets the leader knowledge about the units combat capabilities. ! The leader will be found based on the group id of the entity. !

| Param | Description |
|---|---|
| entityId | AI's entity id |
| unitProperties | binary mask of unit properties type for which the attack is requested ! (in the form of UPR_* + UPR* i.e. UPR_COMBAT_GROUND + UPR_COMBAT_FLIGHT) ! see IAgent.h for definition of unit properties UPR_* |

docs: y · retail: confirmed (binary, runtime dump)

### SetUseSecondaryVehicleWeapon

```lua
AI.SetUseSecondaryVehicleWeapon(entityId, bUseSecondary)
```

Sets if the AI should use the secondary weapon when firing from a vehicle gunner seat if possible.

SetUseSecondaryVehicleWeapon

| Param | Description |
|---|---|
| entityId | AI's entity id |
| bUseSecondary | TRUE to use the secondary weapon |

docs: y · retail: confirmed (binary, runtime dump)

### SetVehicleStickTarget

```lua
AI.SetVehicleStickTarget()
```

C++: `int SetVehicleStickTarget (IFunctionHandler * pH )`

docs: y · retail: confirmed (binary, runtime dump)

### Signal

```lua
AI.Signal(signalFilter, signalType, SignalText, senderId [, signalExtraData])
```

Sends a signal to an entity or a group of entities

| Param | Description |
|---|---|
| signalFilter | filter which defines the subset of AIobjects which will receive the signal: |
| SIGNALFILTER_SENDER | signal is sent to the sender only (may be not the caller itself in this case) |
| SIGNALFILTER_GROUPONLY | signal is sent to all the AIObjects in the same sender's group, within its communication range |
| SIGNALFILTER_GROUPONLY_EXCEPT | signal is sent to all the AIObjects in the same sender's group, within its communication range, except the sender itself |
| SIGNALFILTER_SUPERGROUP | signal is sent signal is sent to all the AIObjects in the same sender's group |
| SIGNALFILTER_SPECIESONLY | signal is sent to all the AIObjects in the same sender's species, in his comm range |
| SIGNALFILTER_SUPERSPECIES | signal is sent to all AIObjects in the same sender's species |
| SIGNALFILTER_ANYONEINCOMM | signal is sent to all the AIObjects in sender's communication range |
| SIGNALFILTER_NEARESTGROUP | signal is sent to the nearest AIObject in the sender's group |
| SIGNALFILTER_NEARESTINCOMM | signal is sent to the nearest AIObject, in the sender's group, within sender's communication range |
| SIGNALFILTER_NEARESTINCOMM_SPECIES | signal is sent to the nearest AIObject, in the sender's species, within sender's communication range |
| SIGNALFILTER_HALFOFGROUP | signal is sent to the first half of the AI Objects in the sender's group |
| SIGNALFILTER_LEADER | signal is sent to the sender's group CLeader Object |
| SIGNALFILTER_LEADERENTITY | signal is sent to the sender's group leader AIObject (which has the CLeader associated) |
| signalType | -1: signal is processed by all entities, even if they're disabled/sleeping 0: signal is processed by all entities which are enabled 1: signal is processed by all entities which are enabled and not sleeping 10: signal is added in the sender's signal queue even if another signal with same text is present (normally it's not) |
| signalText | signal text which will be processed by the receivers (in a Lua callback with the same name as the text, or directly by the CAIObject) (optional) signalExtraData: lua table which can be used to send extra data. It can contains the following values: |
| point | a vector in format {x,y,z} |
| point2 | a vector in format {x,y,z} |
| ObjectName | a string |
| id | an entity id |
| fValue | a float value |
| iValue | an integer value |
| iValue2 | a second integer value |

docs: y · retail: confirmed (binary, runtime dump, vanilla×5 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/AI/AISpawner.lua`))

### SmartObjectEvent

```lua
AI.SmartObjectEvent(actionName, userEntityId, objectEntityId [, vRefPoint])
```

Executes a smart action.

| Param | Description |
|---|---|
| actionName | smart action name |
| usedEntityId | entity id of the user who needs to execute the smart action or a nil if user is unknown |
| objectEntityId | entity id of the object on which the smart action needs to be executed or a nil if objects is unknown |
| vRefPoint | (optional) point to be used instead of user's attention target position |

Returns: 0 if smart object rule wasn't found or a non-zero unique id of the goal pipe inserted to execute the action.

docs: y · retail: confirmed (binary, runtime dump)

### SoundEvent

```lua
AI.SoundEvent(position, radius, threat, interest, entityId)
```

Generates a sound event in the AI system with the given parameters.

| Param | Description |
|---|---|
| position | of the origin of the sound event |
| radius | in which this sound event should be heard |
| threat | value of the sound event |
| interest | value of the sound event |
| entityId | of the entity who generated this sound event |

docs: y · retail: confirmed (binary, runtime dump)

### StartCoordinationWithEntity

```lua
AI.StartCoordinationWithEntity(groupID, coordinationName, entityID)
```

C++: `int StartCoordinationWithEntity (IFunctionHandler* pH , int groupID , const char * pCoordinationName , ScriptHandle entityID )`

docs: y · retail: unconfirmed

### StartCoordinationWithSelectMembers

```lua
AI.StartCoordinationWithSelectMembers(coordinationName, validMembers)
```

C++: `int StartCoordinationWithSelectMembers (IFunctionHandler* pH , const char * pCoordinationName , SmartScriptTable validMembers )`

docs: y · retail: unconfirmed

### StartModularBehaviorTree

```lua
AI.StartModularBehaviorTree()
```

C++: `int StartModularBehaviorTree (IFunctionHandler* pH , ScriptHandle entityIdHandle , const char * treeName )`

This is StartModularBehaviorTree, a member of class CScriptBind_AI.

docs: y · retail: confirmed (binary, runtime dump)

### StopCommunication

```lua
AI.StopCommunication(playID)
```

Stops given communication.

Syntax: AI.StopCommunication(playID)

Stops given communication.

| Param | Description |
|---|---|
| ScriptHandle playID | The id of the communication to stop. The id of the communication to stop. |

docs: y · retail: confirmed (binary, runtime dump)

### StopCoordination

```lua
AI.StopCoordination(coordinationID)
```

C++: `int StopCoordination (IFunctionHandler* pH , ScriptHandle coordinationID )`

docs: y · retail: unconfirmed

### StopCoordinationForActor

```lua
AI.StopCoordinationForActor(coordinationID, entityId)
```

C++: `int StopCoordinationForActor (IFunctionHandler* pH , ScriptHandle coordinationID , ScriptHandle entityID )`

docs: y · retail: unconfirmed

### StopModularBehaviorTree

```lua
AI.StopModularBehaviorTree()
```

C++: `int StopModularBehaviorTree (IFunctionHandler* pH , ScriptHandle entityIdHandle )`

This is StopModularBehaviorTree, a member of class CScriptBind_AI.

docs: y · retail: confirmed (binary, runtime dump)

### ThrowGrenade

```lua
AI.ThrowGrenade(entityId, grenadeType, regTargetType)
```

Throws a specified grenade at target type without interrupting fire mode.

| Param | Description |
|---|---|
| entityId | AI's entity id |
| grenadeType | Requested grenade type (see ERequestedGrenadeType) |
| regTargetType | Who to throw at (see AI_REG_*) |

docs: y · retail: confirmed (binary, runtime dump)

### TriggerCurrentTargetTrackPulse

```lua
AI.TriggerCurrentTargetTrackPulse()
```

C++: `int TriggerCurrentTargetTrackPulse (IFunctionHandler* pH , ScriptHandle entityID , const char * stimulusName , const char * pulseName )`

This is TriggerCurrentTargetTrackPulse, a member of class CScriptBind_AI.

docs: y · retail: confirmed (binary, runtime dump)

### UnregisterInterestedActor

```lua
AI.UnregisterInterestedActor(entityId)
```

Unregisters the entity with the interest system. Any errors go to the error log.

| Param | Description |
|---|---|
| ScriptHandle entityId | AI's entity id |

docs: y · retail: confirmed (binary, runtime dump)

### UnregisterInterestingEntity

```lua
AI.UnregisterInterestingEntity(entityId)
```

Unregisters the entity with the interest system. Any errors go to the error log.

| Param | Description |
|---|---|
| ScriptHandle entityId | AI's entity |

docs: y · retail: confirmed (binary, runtime dump)

### UnregisterTargetTrack

```lua
AI.UnregisterTargetTrack(entityId)
```

Unregisters the AI object with the target track manager.

| Param | Description |
|---|---|
| entityId | AI's entity id |

Returns: True if unregistration was successful. Note that this does nothing if 'ai_TargetTracking' is not set to '2'.

docs: y · retail: confirmed (binary, runtime dump)

### UpdateGlobalPerceptionScale

```lua
AI.UpdateGlobalPerceptionScale(visualScale, audioScale, [filterType], [faction])
```

C++: `int UpdateGlobalPerceptionScale (IFunctionHandler* pH , float visualScale , float audioScale )`

docs: y · retail: confirmed (binary, runtime dump)

### UpdateTempTarget

```lua
AI.UpdateTempTarget(entityId, vPos)
```

Updates the entity's temporary potential target to the given position.

| Param | Description |
|---|---|
| entityId | AI's entity id |
| vPos | New position of the temporary target |

Returns: true if updated

docs: y · retail: confirmed (binary, runtime dump)

### UpTargetPriority

```lua
AI.UpTargetPriority(entityId, targetId, increment)
```

modifies the current entity's target priority for the given target if the given target is among the entity's target list.

| Param | Description |
|---|---|
| entityId | AI's entity id |
| targetId | target's entity id |
| increment | value to modify the target's priority |

docs: y · retail: confirmed (binary, runtime dump)

### VisualEvent

```lua
AI.VisualEvent(entityId, targetId)
```

Generates a visual event in the AI system with the given parameters.

| Param | Description |
|---|---|
| entityId | who receives the visual event |
| targetId | who the receiver is seeing |

docs: y · retail: confirmed (binary, runtime dump)

### Warning

```lua
AI.Warning(szMessage)
```

Used for warnings about data/script errors.

Warning

| Param | Description |
|---|---|
| szMessage | message line to be displayed in log |

docs: y · retail: confirmed (binary, runtime dump)

## Undocumented (present in retail, not in official docs)

### AllowLowerBodyToTurn

`AI.AllowLowerBodyToTurn(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (binary, runtime dump)

### AssignPFPropertiesToPathType

`AI.AssignPFPropertiesToPathType(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (binary, runtime dump, vanilla×1 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/AI/pathfindProperties.lua`))

### ClearMovementContext

`AI.ClearMovementContext(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (binary, runtime dump)

### DestroyAllTPSQueries

`AI.DestroyAllTPSQueries(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (binary, runtime dump)

### GetDirectAnchorPos

`AI.GetDirectAnchorPos(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (binary, runtime dump)

### GetFormationPointClass

`AI.GetFormationPointClass(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (binary, runtime dump)

### GetPathLoop

`AI.GetPathLoop(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (binary, runtime dump)

### GetPointOnPathBySegNo

`AI.GetPointOnPathBySegNo(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (binary, runtime dump)

### IntersectsForbidden

`AI.IntersectsForbidden(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (binary, runtime dump, mod×2)

### IsPointInWaterRegion

`AI.IsPointInWaterRegion(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (binary, runtime dump)

### SetPFProperties

`AI.SetPFProperties(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (binary, runtime dump)
