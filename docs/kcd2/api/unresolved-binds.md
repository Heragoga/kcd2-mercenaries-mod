# Unresolved binary binds

Names registered in the retail binary's Lua bind table (`whgame.sqlite`'s `binds`) whose
owning Lua table could not be determined: not in the official docs, not in the runtime Lua
state dump under any known table, and no other name registered by the same C++ registrar
function resolved to a table either (see [README.md](README.md) for the resolution method).
Many of these look like **entity property/schema field names** (e.g. `ConeAngle`,
`Damping`, `Gravity`, `DawnTime`) rather than callable functions -- likely CryEngine entity
property registrations picked up by the same binary scan, not ScriptBind Lua functions.
Treat this list as leads to investigate, not a ready-to-use API surface.

### __add

binary: y, runtime dump: n, vanilla uses: 0

### __div

binary: y, runtime dump: n, vanilla uses: 0

### __index

binary: y, runtime dump: y, vanilla uses: 0

### __mul

binary: y, runtime dump: n, vanilla uses: 0

### __newindex

binary: y, runtime dump: y, vanilla uses: 0

### __pow

binary: y, runtime dump: n, vanilla uses: 0

### __sub

binary: y, runtime dump: n, vanilla uses: 0

### __tostring

binary: y, runtime dump: n, vanilla uses: 0

### __unm

binary: y, runtime dump: n, vanilla uses: 0

### _index

binary: y, runtime dump: n, vanilla uses: 0

### AddAllCodexPerks

binary: y, runtime dump: n, vanilla uses: 1

### AddInterrupt

binary: y, runtime dump: n, vanilla uses: 0

### AirResistance

binary: y, runtime dump: n, vanilla uses: 0

### alignment

binary: y, runtime dump: n, vanilla uses: 0

### alt_f11

binary: y, runtime dump: n, vanilla uses: 0

### Amount

binary: y, runtime dump: n, vanilla uses: 0

### animation

binary: y, runtime dump: n, vanilla uses: 0

### animHelper

binary: y, runtime dump: n, vanilla uses: 0

### AtomicCallback

binary: y, runtime dump: n, vanilla uses: 0

### behaviorInfo

binary: y, runtime dump: n, vanilla uses: 0

### BendStiffness

binary: y, runtime dump: n, vanilla uses: 0

### BendStiffnessByTrianglesAngle

binary: y, runtime dump: n, vanilla uses: 0

### BlendControlJointName

binary: y, runtime dump: n, vanilla uses: 0

### bool

binary: y, runtime dump: n, vanilla uses: 0

### ButtonMashingSequence

binary: y, runtime dump: n, vanilla uses: 0

### ButtonMashingSequenceSystemX

binary: y, runtime dump: n, vanilla uses: 0

### Callback

binary: y, runtime dump: n, vanilla uses: 0

### CallBehavior

binary: y, runtime dump: n, vanilla uses: 0

### Camera

binary: y, runtime dump: n, vanilla uses: 0

### Capsule

binary: y, runtime dump: n, vanilla uses: 0

### CartNotification

binary: y, runtime dump: n, vanilla uses: 0

### Category

binary: y, runtime dump: n, vanilla uses: 0

### CheckAnimationRewind

binary: y, runtime dump: n, vanilla uses: 0

### CollideEveryNthStep

binary: y, runtime dump: n, vanilla uses: 0

### CollisionDampingTangential

binary: y, runtime dump: n, vanilla uses: 0

### CollisionMode

binary: y, runtime dump: n, vanilla uses: 0

### combat

binary: y, runtime dump: n, vanilla uses: 0

### combatSimulatorGameData

binary: y, runtime dump: n, vanilla uses: 0

### combatSimulatorResult

binary: y, runtime dump: n, vanilla uses: 0

### combatZones

binary: y, runtime dump: n, vanilla uses: 0

### Commit

binary: y, runtime dump: y, vanilla uses: 0

### Condition

binary: y, runtime dump: n, vanilla uses: 0

### ConeAngle

binary: y, runtime dump: n, vanilla uses: 0

### ConeRotation

binary: y, runtime dump: n, vanilla uses: 0

### Create

binary: y, runtime dump: y, vanilla uses: 12

### crime

binary: y, runtime dump: n, vanilla uses: 0

### CurrentStackPrice

binary: y, runtime dump: n, vanilla uses: 0

### CurrentUnitPrice

binary: y, runtime dump: n, vanilla uses: 0

### Cycle

binary: y, runtime dump: n, vanilla uses: 0

### Damping

binary: y, runtime dump: n, vanilla uses: 0

### DawnTime

binary: y, runtime dump: n, vanilla uses: 0

### DebugText

binary: y, runtime dump: n, vanilla uses: 0

### DefaultOneshotResource

binary: y, runtime dump: n, vanilla uses: 0

### DefaultStanceResource

binary: y, runtime dump: n, vanilla uses: 0

### DefaultUnstanceResource

binary: y, runtime dump: n, vanilla uses: 0

### DefaultValue

binary: y, runtime dump: n, vanilla uses: 0

### DerivedComponents

binary: y, runtime dump: n, vanilla uses: 0

### destroyedWeapon

binary: y, runtime dump: n, vanilla uses: 0

### dice_badge_use

binary: y, runtime dump: n, vanilla uses: 0

### dice_exit_badge_effect

binary: y, runtime dump: n, vanilla uses: 0

### dice_hold

binary: y, runtime dump: n, vanilla uses: 0

### dice_pass

binary: y, runtime dump: n, vanilla uses: 0

### dice_score

binary: y, runtime dump: n, vanilla uses: 0

### diceEvent

binary: y, runtime dump: n, vanilla uses: 0

### diceEventBadgeInfo

binary: y, runtime dump: n, vanilla uses: 0

### DirTransJoint

binary: y, runtime dump: n, vanilla uses: 0

### disableFocusAutoRelease

binary: y, runtime dump: n, vanilla uses: 0

### DisableRestock

binary: y, runtime dump: n, vanilla uses: 0

### DisableSimulationTimeRange

binary: y, runtime dump: n, vanilla uses: 0

### DuskTime

binary: y, runtime dump: n, vanilla uses: 0

### Elements

binary: y, runtime dump: n, vanilla uses: 0

### EnableBehavior

binary: y, runtime dump: n, vanilla uses: 0

### EndPosition

binary: y, runtime dump: n, vanilla uses: 0

### entityInfo

binary: y, runtime dump: n, vanilla uses: 0

### FilterLaplace

binary: y, runtime dump: n, vanilla uses: 0

### findFocus

binary: y, runtime dump: n, vanilla uses: 0

### fireData

binary: y, runtime dump: n, vanilla uses: 0

### float

binary: y, runtime dump: n, vanilla uses: 0

### ForceSkinning

binary: y, runtime dump: n, vanilla uses: 0

### Friction

binary: y, runtime dump: n, vanilla uses: 0

### gameVersion

binary: y, runtime dump: n, vanilla uses: 0

### GetBaseReputation

binary: y, runtime dump: n, vanilla uses: 0

### GetCategory

binary: y, runtime dump: n, vanilla uses: 0

### getControllerFocusGroup

binary: y, runtime dump: n, vanilla uses: 0

### getFocusArray

binary: y, runtime dump: n, vanilla uses: 0

### getFocusBitmask

binary: y, runtime dump: n, vanilla uses: 0

### getIMECandidateListStyle

binary: y, runtime dump: n, vanilla uses: 0

### getInputLanguage

binary: y, runtime dump: n, vanilla uses: 0

### GetLocationId

binary: y, runtime dump: n, vanilla uses: 0

### getModalClip

binary: y, runtime dump: n, vanilla uses: 0

### GetNameStringId

binary: y, runtime dump: n, vanilla uses: 0

### GetPhaseById

binary: y, runtime dump: n, vanilla uses: 0

### GetPosition

binary: y, runtime dump: n, vanilla uses: 0

### GetReputation

binary: y, runtime dump: n, vanilla uses: 0

### Gravity

binary: y, runtime dump: n, vanilla uses: 0

### Ground

binary: y, runtime dump: n, vanilla uses: 0

### GroundFall

binary: y, runtime dump: n, vanilla uses: 0

### GroundMovement

binary: y, runtime dump: n, vanilla uses: 0

### haltingReason

binary: y, runtime dump: n, vanilla uses: 0

### HasArrived

binary: y, runtime dump: n, vanilla uses: 0

### Health

binary: y, runtime dump: n, vanilla uses: 0

### hearingInfo

binary: y, runtime dump: n, vanilla uses: 0

### helperInfo

binary: y, runtime dump: n, vanilla uses: 0

### horse_inspect_close

binary: y, runtime dump: n, vanilla uses: 0

### imecommand

binary: y, runtime dump: n, vanilla uses: 0

### IncludeTree

binary: y, runtime dump: n, vanilla uses: 0

### informationDiff

binary: y, runtime dump: n, vanilla uses: 0

### informationTagChanged

binary: y, runtime dump: n, vanilla uses: 0

### InteractiveAction

binary: y, runtime dump: n, vanilla uses: 0

### Inventory

binary: y, runtime dump: n, vanilla uses: 0

### IsDeprecated

binary: y, runtime dump: n, vanilla uses: 0

### IsDiscovered

binary: y, runtime dump: n, vanilla uses: 0

### IsInCombatMode

binary: y, runtime dump: n, vanilla uses: 1

### IsPaused

binary: y, runtime dump: n, vanilla uses: 0

### IsPhaseModelLoaded

binary: y, runtime dump: n, vanilla uses: 1

### IsWanted

binary: y, runtime dump: n, vanilla uses: 0

### ItemClass

binary: y, runtime dump: n, vanilla uses: 0

### ItemDescriptor

binary: y, runtime dump: n, vanilla uses: 0

### itemPrescriptor

binary: y, runtime dump: n, vanilla uses: 0

### ItemSlotBook

binary: y, runtime dump: n, vanilla uses: 0

### ItemSlotMultiClass

binary: y, runtime dump: n, vanilla uses: 0

### ItemSlotPile

binary: y, runtime dump: n, vanilla uses: 0

### ItemTransfer

binary: y, runtime dump: n, vanilla uses: 0

### JointSpring

binary: y, runtime dump: n, vanilla uses: 0

### Labels

binary: y, runtime dump: n, vanilla uses: 0

### lastHit

binary: y, runtime dump: n, vanilla uses: 0

### Ledge

binary: y, runtime dump: n, vanilla uses: 0

### LoadOriginalModel

binary: y, runtime dump: n, vanilla uses: 2

### LoadPhaseModel

binary: y, runtime dump: n, vanilla uses: 2

### Localization

binary: y, runtime dump: n, vanilla uses: 0

### lockpickedDoorData

binary: y, runtime dump: n, vanilla uses: 0

### master_master

binary: y, runtime dump: n, vanilla uses: 0

### MaxAngle

binary: y, runtime dump: n, vanilla uses: 0

### MaxAnimDistance

binary: y, runtime dump: n, vanilla uses: 0

### MaxQuality

binary: y, runtime dump: n, vanilla uses: 0

### MinAngularDiff

binary: y, runtime dump: n, vanilla uses: 0

### MovementRoot

binary: y, runtime dump: n, vanilla uses: 0

### MoveTo

binary: y, runtime dump: n, vanilla uses: 0

### Name

binary: y, runtime dump: n, vanilla uses: 0

### name

binary: y, runtime dump: n, vanilla uses: 0

### NewStackPrice

binary: y, runtime dump: n, vanilla uses: 0

### NewUnitPrice

binary: y, runtime dump: n, vanilla uses: 0

### NndcAllowedExtension

binary: y, runtime dump: n, vanilla uses: 0

### NndcMaximumShiftFactor

binary: y, runtime dump: n, vanilla uses: 0

### NndcShiftCollisionFactor

binary: y, runtime dump: n, vanilla uses: 0

### npcDeath

binary: y, runtime dump: n, vanilla uses: 0

### npcEmergency

binary: y, runtime dump: n, vanilla uses: 0

### numFocusGroups

binary: y, runtime dump: n, vanilla uses: 0

### NumIterations

binary: y, runtime dump: n, vanilla uses: 0

### OnAfterDeserialization

binary: y, runtime dump: n, vanilla uses: 0

### OnButton

binary: y, runtime dump: n, vanilla uses: 0

### OnClosed

binary: y, runtime dump: n, vanilla uses: 0

### OnCombineDialogCancelClicked

binary: y, runtime dump: n, vanilla uses: 0

### OnCombineDialogConfirmClicked

binary: y, runtime dump: n, vanilla uses: 0

### OnCombineDialogSelectClicked

binary: y, runtime dump: n, vanilla uses: 0

### OnConfirm

binary: y, runtime dump: n, vanilla uses: 0

### OnCursorOnActiveAreaChanged

binary: y, runtime dump: n, vanilla uses: 0

### OnDialogHided

binary: y, runtime dump: n, vanilla uses: 0

### OnDoubleClicked

binary: y, runtime dump: n, vanilla uses: 0

### OnFaderSuspend

binary: y, runtime dump: n, vanilla uses: 0

### OnFocusTab

binary: y, runtime dump: n, vanilla uses: 0

### OnGamaButtonFocus

binary: y, runtime dump: n, vanilla uses: 0

### OnGeneralEvent

binary: y, runtime dump: n, vanilla uses: 0

### OnGetHealEffect

binary: y, runtime dump: n, vanilla uses: 0

### OnGetProsQRCode

binary: y, runtime dump: n, vanilla uses: 0

### OnHealingDialogCancelClicked

binary: y, runtime dump: n, vanilla uses: 0

### OnHealingDialogConfirmClicked

binary: y, runtime dump: n, vanilla uses: 0

### OnHideQAMSlotArrows

binary: y, runtime dump: n, vanilla uses: 0

### OnHideTooltip

binary: y, runtime dump: n, vanilla uses: 0

### OnHighlightFastTravelPoint

binary: y, runtime dump: n, vanilla uses: 0

### OnHighlightOutfit

binary: y, runtime dump: n, vanilla uses: 0

### OnHighlightTab

binary: y, runtime dump: n, vanilla uses: 0

### OnInteractiveChoice

binary: y, runtime dump: n, vanilla uses: 0

### OnInteractiveValue

binary: y, runtime dump: n, vanilla uses: 0

### OnOpened

binary: y, runtime dump: n, vanilla uses: 0

### OnOpenWebPage

binary: y, runtime dump: n, vanilla uses: 0

### OnOpenWebPageSocial

binary: y, runtime dump: n, vanilla uses: 0

### OnOutfitClicked

binary: y, runtime dump: n, vanilla uses: 0

### OnScreenButton

binary: y, runtime dump: n, vanilla uses: 0

### OnSetFaderState

binary: y, runtime dump: n, vanilla uses: 0

### OnShowTooltip

binary: y, runtime dump: n, vanilla uses: 0

### OnStartDrag

binary: y, runtime dump: n, vanilla uses: 0

### OnStatsSimulation

binary: y, runtime dump: n, vanilla uses: 0

### OnUnfocusTab

binary: y, runtime dump: n, vanilla uses: 0

### OnUnhighlightFastTravelPoint

binary: y, runtime dump: n, vanilla uses: 0

### OnUnhighlightOutfit

binary: y, runtime dump: n, vanilla uses: 0

### OnUnhighlightTab

binary: y, runtime dump: n, vanilla uses: 0

### open_skiptime

binary: y, runtime dump: n, vanilla uses: 0

### Parameters

binary: y, runtime dump: n, vanilla uses: 0

### ParticleEffect

binary: y, runtime dump: n, vanilla uses: 0

### pathFindingParams

binary: y, runtime dump: n, vanilla uses: 0

### pathInfo

binary: y, runtime dump: n, vanilla uses: 0

### perceivedWuid

binary: y, runtime dump: n, vanilla uses: 0

### perceptibleParams

binary: y, runtime dump: n, vanilla uses: 0

### perceptionInfo

binary: y, runtime dump: n, vanilla uses: 0

### perfectBlockProbability

binary: y, runtime dump: n, vanilla uses: 0

### PivotOffset

binary: y, runtime dump: n, vanilla uses: 0

### predefinedPathParams

binary: y, runtime dump: n, vanilla uses: 0

### proximityInfo

binary: y, runtime dump: n, vanilla uses: 0

### ProxyMeshMemoryUsage

binary: y, runtime dump: n, vanilla uses: 0

### ProxyMeshStreamingStatus

binary: y, runtime dump: n, vanilla uses: 0

### ProxyNames

binary: y, runtime dump: n, vanilla uses: 0

### ProxyTextureMemoryUsage

binary: y, runtime dump: n, vanilla uses: 0

### PullStiffness

binary: y, runtime dump: n, vanilla uses: 0

### Purpose

binary: y, runtime dump: n, vanilla uses: 0

### r_D3D12HardwareComputeQueue

binary: y, runtime dump: n, vanilla uses: 0

### r_D3D12HardwareCopyQueue

binary: y, runtime dump: n, vanilla uses: 0

### Race

binary: y, runtime dump: n, vanilla uses: 0

### Radius

binary: y, runtime dump: n, vanilla uses: 0

### Redirect

binary: y, runtime dump: n, vanilla uses: 0

### RelaxationLoops

binary: y, runtime dump: n, vanilla uses: 0

### Reputation

binary: y, runtime dump: n, vanilla uses: 0

### ReputationChangeTarget

binary: y, runtime dump: n, vanilla uses: 0

### ResetDampingFactor

binary: y, runtime dump: n, vanilla uses: 0

### ResetDampingRange

binary: y, runtime dump: n, vanilla uses: 0

### ResetUsed

binary: y, runtime dump: n, vanilla uses: 0

### Result

binary: y, runtime dump: n, vanilla uses: 0

### Revert

binary: y, runtime dump: y, vanilla uses: 0

### RigidDamping

binary: y, runtime dump: n, vanilla uses: 0

### RodLength

binary: y, runtime dump: n, vanilla uses: 0

### Root

binary: y, runtime dump: n, vanilla uses: 0

### RotateToAngles

binary: y, runtime dump: n, vanilla uses: 0

### Roughness

binary: y, runtime dump: n, vanilla uses: 0

### rpgModule

binary: y, runtime dump: n, vanilla uses: 0

### screenToWorld

binary: y, runtime dump: n, vanilla uses: 0

### senderInfo

binary: y, runtime dump: n, vanilla uses: 0

### setControllerFocusGroup

binary: y, runtime dump: n, vanilla uses: 0

### setIMECandidateListStyle

binary: y, runtime dump: n, vanilla uses: 0

### SetItemHealth

binary: y, runtime dump: n, vanilla uses: 0

### SetItemPhaseId

binary: y, runtime dump: n, vanilla uses: 0

### setModalClip

binary: y, runtime dump: n, vanilla uses: 0

### ShearStiffness

binary: y, runtime dump: n, vanilla uses: 0

### SimFPS

binary: y, runtime dump: n, vanilla uses: 0

### SkillcheckCondition

binary: y, runtime dump: n, vanilla uses: 0

### smartBehaviorHostInfo

binary: y, runtime dump: n, vanilla uses: 0

### Souls

binary: y, runtime dump: n, vanilla uses: 0

### soulToMetaroles

binary: y, runtime dump: n, vanilla uses: 0

### SphereScale

binary: y, runtime dump: n, vanilla uses: 0

### SpringDamping

binary: y, runtime dump: n, vanilla uses: 0

### SpringDampingPerSubstep

binary: y, runtime dump: n, vanilla uses: 0

### staminaPolicy

binary: y, runtime dump: n, vanilla uses: 0

### stealData

binary: y, runtime dump: n, vanilla uses: 0

### steam

binary: y, runtime dump: n, vanilla uses: 0

### Stiffness

binary: y, runtime dump: n, vanilla uses: 0

### StiffnessTarget

binary: y, runtime dump: n, vanilla uses: 0

### stopFight

binary: y, runtime dump: n, vanilla uses: 0

### StreamingStatus

binary: y, runtime dump: n, vanilla uses: 0

### StrengthArray

binary: y, runtime dump: n, vanilla uses: 0

### Stretch

binary: y, runtime dump: n, vanilla uses: 0

### StretchStiffness

binary: y, runtime dump: n, vanilla uses: 0

### string

binary: y, runtime dump: n, vanilla uses: 0

### string_view

binary: y, runtime dump: n, vanilla uses: 0

### Subtype

binary: y, runtime dump: n, vanilla uses: 0

### TagPoint

binary: y, runtime dump: n, vanilla uses: 0

### TimeStep

binary: y, runtime dump: n, vanilla uses: 0

### TimeStepsMax

binary: y, runtime dump: n, vanilla uses: 0

### TranslationAxis

binary: y, runtime dump: n, vanilla uses: 0

### TryBeard

binary: y, runtime dump: y, vanilla uses: 0

### TryHair

binary: y, runtime dump: y, vanilla uses: 0

### Type

binary: y, runtime dump: n, vanilla uses: 0

### UIName

binary: y, runtime dump: n, vanilla uses: 0

### UnstanceResources

binary: y, runtime dump: n, vanilla uses: 0

### UpdatePriority

binary: y, runtime dump: n, vanilla uses: 0

### UseNearestNeighborDistanceConstraints

binary: y, runtime dump: n, vanilla uses: 0

### ValueOriginConstraint

binary: y, runtime dump: n, vanilla uses: 0

### Visibility

binary: y, runtime dump: n, vanilla uses: 0

### WashItem

binary: y, runtime dump: n, vanilla uses: 0

### WH_AI_CombatMove_CirclingLowestMovementActivity

binary: y, runtime dump: n, vanilla uses: 0

### wh_ai_LogBodiesFilter

binary: y, runtime dump: n, vanilla uses: 0

### wh_ai_ReloadConfiguration

binary: y, runtime dump: n, vanilla uses: 0

### wh_r_DynamicLightTimes

binary: y, runtime dump: n, vanilla uses: 0

### wh_ui_EnableSubtitleBg

binary: y, runtime dump: n, vanilla uses: 0

### wh_ui_EnableSubtitleSpeakerName

binary: y, runtime dump: n, vanilla uses: 0

### wh_ui_photomodeGrid

binary: y, runtime dump: n, vanilla uses: 0

### wh_ui_photomodeLogoPosition

binary: y, runtime dump: n, vanilla uses: 0

### wh_ui_photomodeVignetteRadius

binary: y, runtime dump: n, vanilla uses: 0

### wh_ui_SubtitleSize

binary: y, runtime dump: n, vanilla uses: 0
