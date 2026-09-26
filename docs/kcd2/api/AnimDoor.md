# AnimDoor

C++ class(es): `C_ScriptBindAnimDoor`
Reached from Lua as `AnimDoor.FunctionName(...)`.
9 documented function(s); 53 additional undocumented function(s) found in retail/runtime.

## Functions

### AttachTo

```lua
AnimDoor.AttachTo()
```

C++: `virtual void AttachTo (C_AnimDoor* door )`

docs: y · retail: unconfirmed

### GetDoor

```lua
AnimDoor.GetDoor()
```

C++: `C_AnimDoor* GetDoor (IFunctionHandler* pH )`

docs: y · retail: unconfirmed

### GetObjectAnim

```lua
animDoor.GetObjectAnim(userId, true, false, true)
```

Gets the animation name that should be played by the door object based on the situation and usage specified by the params

| Param | Description |
|---|---|
| ScriptHandle userId | entity id of user of the door (typically player or npc) |
| bool isOpened | is the door currently opened |
| bool shouldBeOpened | should the door be opened after the usage |
| bool isFrontSide | is the door used from the front side |

docs: y · retail: unconfirmed

### GetSoul

```lua
AnimDoor.GetSoul()
```

C++: `rpgmodule::I_Soul* GetSoul (UINT_PTR userId )`

docs: y · retail: unconfirmed

### GetUserAnimName

```lua
animDoor.GetUserAnimName(userId, true, false, true)
```

Gets the animation name that should be played by the user of the door when using the door.

| Param | Description |
|---|---|
| ScriptHandle userId | entity id of user of the door (typically player or npc) |
| bool isOpened | is the door currently opened |
| bool shouldBeOpened | should the door be opened after the usage |
| bool isFrontSide | is the door used from the front side |

docs: y · retail: confirmed (binary, vanilla×1)

### IsEndPointInPrivateArea

```lua
animDoor.IsEndPointInPrivateArea()
```

C++: `int IsEndPointInPrivateArea (IFunctionHandler* pH )`

Returns true if any of the door's navigation endpoint is within a private area

docs: y · retail: confirmed (binary)

### ReportClosed

```lua
animDoor.ReportClosed(userId)
```

C++: `virtual int ReportClosed (IFunctionHandler* pH , ScriptHandle userId )`

Should be called when the door is closed.

docs: y · retail: confirmed (vanilla×2)

### ReportOpened

```lua
animDoor.ReportOpened(userId)
```

C++: `virtual int ReportOpened (IFunctionHandler* pH , ScriptHandle userId )`

Should be called when the door is opened.

docs: y · retail: confirmed (vanilla×2)

### UpdateBeforeAnimation

```lua
animDoor.UpdateBeforeAnimation()
```

C++: `virtual int UpdateBeforeAnimation (IFunctionHandler* pH )`

Should be called when an animation is about to be played on the door so that the C_AnimDoor object has the chance to update some internal information before the animation starts, incl. audio settings.

docs: y · retail: confirmed (vanilla×1)

## Undocumented (present in retail, not in official docs)

### BuildNPCAnimationName

`AnimDoor.BuildNPCAnimationName(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×2)

### BuildObjectAnimationName

`AnimDoor.BuildObjectAnimationName(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×2)

### Close

`AnimDoor.Close(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×9)

### DespawnSuspiciousVolume

`AnimDoor.DespawnSuspiciousVolume(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×2)

### DisableLockpick

`AnimDoor.DisableLockpick(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×1)

### DoLockOnMissingHomeArea

`AnimDoor.DoLockOnMissingHomeArea(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×1)

### DoPlayAnimation

`AnimDoor.DoPlayAnimation(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×12)

### DoPlaySound

`AnimDoor.DoPlaySound(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×6)

### DoStopSound

`AnimDoor.DoStopSound(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×14)

### DumpState

`AnimDoor.DumpState(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×1)

### EnableLockpick

`AnimDoor.EnableLockpick(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×1)

### Event_Close

`AnimDoor.Event_Close(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×5)

### Event_Hide

`AnimDoor.Event_Hide(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×25)

### Event_Lock

`AnimDoor.Event_Lock(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×3)

### Event_Open

`AnimDoor.Event_Open(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×6)

### Event_UnHide

`AnimDoor.Event_UnHide(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×18)

### Event_Unlock

`AnimDoor.Event_Unlock(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×3)

### GenerateLockData

`AnimDoor.GenerateLockData(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×4)

### GetActions

`AnimDoor.GetActions(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×35, mod×1)

### GetLockDifficulty

`AnimDoor.GetLockDifficulty(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×3)

### GetObjectAnimName

`AnimDoor.GetObjectAnimName(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (binary, vanilla×1)

### GetSuspiciousVolume

`AnimDoor.GetSuspiciousVolume(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×3)

### IsAccessedFromFront

`AnimDoor.IsAccessedFromFront(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×5)

### IsInteractive

`AnimDoor.IsInteractive(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (binary, runtime dump, vanilla×5)

### IsInUse

`AnimDoor.IsInUse(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×3)

### IsLocked

`AnimDoor.IsLocked(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×2)

### IsOnKeySide

`AnimDoor.IsOnKeySide(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×6)

### IsOpen

`AnimDoor.IsOpen(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×4)

### IsRightDoor

`AnimDoor.IsRightDoor(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×1)

### IsUsable

`AnimDoor.IsUsable(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×47, mod×1)

### IsUsableMsgChanged

`AnimDoor.IsUsableMsgChanged(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×9, mod×1)

### Lock

`AnimDoor.Lock(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×14)

### Lockpick

`AnimDoor.Lockpick(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×1)

### NeedSerialize

`AnimDoor.NeedSerialize(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×5)

### OnEnablePhysics

`AnimDoor.OnEnablePhysics(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×7)

### OnLoad

`AnimDoor.OnLoad(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×65, mod×1)

### OnPropertyChange

`AnimDoor.OnPropertyChange(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×113)

### OnReset

`AnimDoor.OnReset(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×162, mod×2)

### OnSave

`AnimDoor.OnSave(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×60, mod×1)

### OnSpawn

`AnimDoor.OnSpawn(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×75, mod×4)

### OnUsed

`AnimDoor.OnUsed(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (binary, runtime dump, vanilla×36, mod×1)

### Open

`AnimDoor.Open(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×9)

### PhysicalizeThis

`AnimDoor.PhysicalizeThis(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×50, mod×2)

### ProduceAiSound

`AnimDoor.ProduceAiSound(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×4)

### Reset

`AnimDoor.Reset(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (binary, runtime dump, vanilla×81)

### SetInteractiveCollisionType

`AnimDoor.SetInteractiveCollisionType(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×36)

### SetLockedDueToPrivate

`AnimDoor.SetLockedDueToPrivate(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×1)

### SetPhysicalFlags

`AnimDoor.SetPhysicalFlags(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×4)

### SetShouldBeLockedOverride

`AnimDoor.SetShouldBeLockedOverride(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×1)

### SetUnlockedDueExpected

`AnimDoor.SetUnlockedDueExpected(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×1)

### ShouldBeLocked

`AnimDoor.ShouldBeLocked(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×2)

### SpawnSuspiciousVolume

`AnimDoor.SpawnSuspiciousVolume(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×2)

### Unlock

`AnimDoor.Unlock(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×12)
