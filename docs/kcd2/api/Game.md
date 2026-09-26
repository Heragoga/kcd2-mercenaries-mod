# Game

C++ class(es): `CScriptBindGame`, `CScriptBind_Game`
Reached from Lua as `Game.FunctionName(...)`.
57 documented function(s); 1 additional undocumented function(s) found in retail/runtime.

## Functions

### AddSaveLock

```lua
Game.AddSaveLock(lockName, uiDescription)
```

Disable save

| Param | Description |
|---|---|
| const char* lockName | id of lock. |
| const char* uiDescription | UI description. If empty: default UI description is displayed |

docs: y · retail: confirmed (runtime dump, vanilla×1 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Utils/GameUtils.lua`))

### AllowTutorials

```lua
Game.AllowTutorials()
```

C++: `int AllowTutorials (IFunctionHandler * pH )`

Allow showing tutorials (eg. after dialogue, cut scene, video, etc.)

docs: y · retail: confirmed (binary, runtime dump)

### AutoSave

```lua
Game.AutoSave()
```

C++: `int AutoSave (IFunctionHandler * pH )`

Creates auto save, returns false if save cannot be done (locked by some event).

docs: y · retail: unconfirmed

### BlockInfoText

```lua
Game.BlockInfoText(category)
```

C++: `int BlockInfoText (IFunctionHandler * pH , int categoryRuntimeId )`

Prevents InfoTexts with given category from being displayed to player. Categories are defined in db table infotext_category (everyone can add there) and are exported to lua as constants with prefix "itc_".

docs: y · retail: unconfirmed

### BlockTutorials

```lua
Game.BlockTutorials()
```

C++: `int BlockTutorials (IFunctionHandler * pH )`

Block all tutorial messages except synced ones.

docs: y · retail: confirmed (binary, runtime dump)

### CacheResource

```lua
Game.CacheResource()
```

C++: `int CacheResource (IFunctionHandler * pH , const char * whoIsRequesting , const char * resourceName , int resourceType , int resourceFlags )`

docs: y · retail: confirmed (runtime dump, vanilla×7 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/Lights/EnvironmentLight.lua`))

### CreatePrefab

```lua
Game.CreatePrefab(ScriptHandle entityId, const char* libname, const char* prefabname, mMaxSpawn)
```

Creates the runtime prefab in the same way as SpawnPrefab, but doesn't spawn the content of the prefab. Only creates the prefab and links to given entity id.

| Param | Description |
|---|---|
| ScriptHandle entityId | id of the procedural object that controls the runtime prefab |
| const char* libname | prefab library name |
| const char* prefabname | name of the prefab |
| mMaxSpawn | limit of the runtime prefabs of this type to be spawned (zero means no limit) |

docs: y · retail: confirmed (binary, runtime dump, vanilla×1 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/Others/RuntimePrefab.lua`))

### CreateSavepoint

```lua
Game.CreateSavepoint(name)
```

DEPRECATED: Creates 'permanent' save

| Param | Description |
|---|---|
| char const* name | name of savegame |

docs: y · retail: unconfirmed

### DEBUG_HideOverlayTutorial

```lua
Game.DEBUG_HideOverlayTutorial()
```

C++: `int DEBUG_HideOverlayTutorial (IFunctionHandler * pH )`

_RELEASE

docs: y · retail: unconfirmed

### DebugDrawAABB

```lua
Game.DebugDrawAABB()
```

C++: `int DebugDrawAABB (IFunctionHandler * pH , float x , float y , float z , float x2 , float y2 , float z2 , int r , int g , int b , int a )`

This is DebugDrawAABB, a member of class CScriptBind_Game.

docs: y · retail: unconfirmed

### DebugDrawCone

```lua
Game.DebugDrawCone()
```

C++: `int DebugDrawCone (IFunctionHandler * pH , float x , float y , float z , float radius , float height , int r , int g , int b , int a )`

This is DebugDrawCone, a member of class CScriptBind_Game.

docs: y · retail: unconfirmed

### DebugDrawCylinder

```lua
Game.DebugDrawCylinder()
```

C++: `int DebugDrawCylinder (IFunctionHandler * pH , float x , float y , float z , float radius , float height , int r , int g , int b , int a )`

Debug

docs: y · retail: confirmed (vanilla×3 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/Others/Ladder.lua`))

### DebugDrawPersistanceDirection

```lua
Game.DebugDrawPersistanceDirection()
```

C++: `int DebugDrawPersistanceDirection (IFunctionHandler * pH , float startX , float startY , float startZ , float dirX , float dirY , float dirZ , int r , int g , int b , float duration )`

This is DebugDrawPersistanceDirection, a member of class CScriptBind_Game.

docs: y · retail: unconfirmed

### DebugDrawText

```lua
Game.DebugDrawText(float x, float y, float fontSize, const char* text, int r, int g, int b, float a)
```

Draws texts on screen, needs to be called in OnUpdate function.

| Param | Description |
|---|---|
| float x | x offset from top left of the screen |
| float y | y offset from top left of the screen |
| float fontSize | font size, 0 for default value of 1.5 |
| const char* text | text to be drawn |
| int r | red |
| int g | green |
| int b | blue |
| float a | 0-1, 1 is visible |

docs: y · retail: unconfirmed

> **Verified note:** Absent in retail -- calling it has no effect. Use `System.DrawText` (debug font, ASCII-only) instead. -- kcd2/ui-scaleform.md#immediate-mode-drawing (verified in game)

### DeletePrefab

```lua
Game.DeletePrefab()
```

C++: `int DeletePrefab (IFunctionHandler* pH , ScriptHandle entityId )`

docs: y · retail: confirmed (binary, runtime dump, vanilla×2 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/Others/RuntimePrefab.lua`), mod×1)

### DiscoveryMessageDebug

```lua
Game.DiscoveryMessageDebug(type, uiName, iconId=-1, perkName="")
```

C++: `int ShowDiscoveryMessageDebug (IFunctionHandler * pH , int type , const char * uiName )`

type is 0=poi, 1=location, 2=codex

docs: y · retail: unconfirmed

### EnableSave

```lua
Game.EnableSave()
```

C++: `int EnableSave (IFunctionHandler * pH , bool state )`

Enable or disable save from script (script save lock)

docs: y · retail: confirmed (vanilla×6)

### GetActionControl

```lua
Game.GetActionControl(actionMap, actionId)
```

Get control mapped for action with given name for current input device.

| Param | Description |
|---|---|
| const char * actionMap | action map name. |
| const char * actionId | action id name. |

docs: y · retail: unconfirmed

### GetNumLightsActivated

```lua
Game.GetNumLightsActivated()
```

C++: `int GetNumLightsActivated (IFunctionHandler * pH )`

Gets the number of activated lights.

docs: y · retail: unconfirmed

### GetPrefabPhase

```lua
Game.GetPrefabPhase()
```

C++: `int GetPrefabPhase (IFunctionHandler* pH , ScriptHandle entityId )`

docs: y · retail: unconfirmed

### HideInfoText

```lua
Game.HideInfoText()
```

C++: `int HideInfoText (IFunctionHandler * pH )`

Hides info text sooner.

docs: y · retail: confirmed (binary, runtime dump)

### HidePrefab

```lua
Game.HidePrefab()
```

C++: `int HidePrefab (IFunctionHandler* pH , ScriptHandle entityId , bool bHide )`

docs: y · retail: confirmed (runtime dump, vanilla×2 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/Others/RuntimePrefab.lua`))

### HideTutorial

```lua
Game.HideTutorial(name)
```

Hides tutorial if currently show. If tutorial is not show right now, nothing happens.

| Param | Description |
|---|---|
| const char* name | id (name) of the tutorial from the tutorials.xml table. |

docs: y · retail: confirmed (binary, runtime dump)

### InventoryModeOnlyCodex

```lua
Game.InventoryModeOnlyCodex(enable)
```

C++: `int InventoryModeOnlyCodex (IFunctionHandler * pH , bool enable )`

Do not allow player to switch to anything else than codex in player inventory. Other inventories (looting, shopping, ...) are not affected.

docs: y · retail: confirmed (runtime dump)

### IsDemo

```lua
Game.IsDemo()
```

C++: `int IsDemo (IFunctionHandler * pH )`

if the code is compiled on a "*Demo*" configuration

docs: y · retail: confirmed (binary, runtime dump)

### IsLoadingEngineSaveGame

```lua
Game.IsLoadingEngineSaveGame()
```

C++: `int IsLoadingEngineSaveGame (IFunctionHandler* pH )`

Determines whether a game save is being loaded (Cry Engine load only!!)

docs: y · retail: confirmed (binary, runtime dump, vanilla×1 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/Others/RuntimePrefab.lua`))

### IsMountedWeaponUsableWithTarget

```lua
Game.IsMountedWeaponUsableWithTarget()
```

C++: `int IsMountedWeaponUsableWithTarget (IFunctionHandler * pH )`

Checks if the mounted weapon is usable with the target.

IsMountedWeaponUsableWithTarget A piece of game-code moved from CryAction when scriptbind_AI moved to the AI system

docs: y · retail: unconfirmed

### IsPlayer

```lua
Game.IsPlayer()
```

C++: `int IsPlayer (IFunctionHandler * pH , ScriptHandle entityId )`

Checks if the given entity is player.

docs: y · retail: confirmed (binary, runtime dump, vanilla×17 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/Triggers/ProximityTrigger.lua`))

### KeybindsRebindInput

```lua
Game.KeybindsRebindInput()
```

C++: `int KeybindsRebindInput (IFunctionHandler * pH , const char * controller , const char * superaction , int slot , const char * input )`

docs: y · retail: confirmed (runtime dump)

### LoadPrefabLibrary

```lua
Game.LoadPrefabLibrary()
```

C++: `int LoadPrefabLibrary (IFunctionHandler* pH , const char * filename )`

docs: y · retail: unconfirmed

### LogGameEvent

```lua
Game.LogGameEvent(text)
```

C++: `int LogGameEvent (IFunctionHandler * pH , const char * message )`

Localization will be done for you (if the message contains @...)

docs: y · retail: confirmed (binary, runtime dump, vanilla×3 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/actor/player.lua`))

### MovePrefab

```lua
Game.MovePrefab()
```

C++: `int MovePrefab (IFunctionHandler* pH , ScriptHandle entityId )`

docs: y · retail: confirmed (binary, runtime dump, vanilla×1 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/Others/RuntimePrefab.lua`))

### PauseGame

```lua
Game.PauseGame(bool pause)
```

Pauses the game.

| Param | Description |
|---|---|
| bool pause | True to pause the game, false to resume. |

docs: y · retail: confirmed (vanilla×1 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/GameRules/SinglePlayer.lua`))

### QueryBattleStatus

```lua
Game.QueryBattleStatus()
```

C++: `int QueryBattleStatus (IFunctionHandler * pH )`

Queries battle status, range from 0 (quiet) to 1 (full combat).

docs: y · retail: confirmed (mod×4)

### QuickLoad

```lua
Game.QuickLoad()
```

C++: `virtual int QuickLoad (IFunctionHandler * pH )`

Quick load

docs: y · retail: confirmed (binary, runtime dump, mod×1)

### QuickSave

```lua
Game.QuickSave()
```

C++: `virtual int QuickSave (IFunctionHandler * pH )`

Quick save

docs: y · retail: confirmed (binary, runtime dump, mod×6)

### RemoveSaveLock

```lua
Game.RemoveSaveLock(lockNamed)
```

Enable save

| Param | Description |
|---|---|
| const char* lockName | id of lock. |

docs: y · retail: confirmed (binary, runtime dump, vanilla×1 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Utils/GameUtils.lua`))

### ResetEntity

```lua
Game.ResetEntity()
```

C++: `int ResetEntity (IFunctionHandler * pH , ScriptHandle entityId )`

This is ResetEntity, a member of class CScriptBindGame.

docs: y · retail: confirmed (binary, runtime dump, vanilla×2 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/PlayerInteractive/InteractiveObjectEx.lua`))

### ResetTutorial

```lua
Game.ResetTutorial(name)
```

Resets the tutorials making it possible to display again.

| Param | Description |
|---|---|
| const char* name | id (name) of the tutorial from the tutorials.xml table. |

docs: y · retail: confirmed (binary, runtime dump)

### SaveGameViaResting

```lua
Game.SaveGameViaResting()
```

C++: `int SaveGameViaResting (IFunctionHandler * pH )`

Creates 'Auto' save

docs: y · retail: confirmed (binary, runtime dump, mod×4)

### SaveLock

```lua
Game.SaveLock()
```

C++: `int SaveLock (IFunctionHandler * pH , const char * lockName , bool lockOn )`

Enable or disable save from script (script save lock) ! Obsolete - use AddSaveLock() or RemoveSaveLock()

docs: y · retail: unconfirmed

### SendInfoText

```lua
Game.SendInfoText(text, [force_clear_current_queue], [category], [time])
```

Shows info text. Does not need to be hidden (hides automaticaly).

| Param | Description |
|---|---|
| const char * text | text to show |
| forceClearCurrentInfoTextQueue | clears currently displayed infotexts; default is false |
| category | see BlockInfoText - use nil or any other non-numeric value to not set any category |
| time | time in seconds /integer value/; use nil, non-numeric or negative value to use default time |

docs: y · retail: confirmed (binary, runtime dump, vanilla×6 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/WH/Triggers/BedTrigger.lua`), mod×184)

### SetPrefabPhase

```lua
Game.SetPrefabPhase()
```

C++: `int SetPrefabPhase (IFunctionHandler* pH , ScriptHandle entityId , const char * categoryName , float phase )`

docs: y · retail: confirmed (runtime dump)

### SetPrefabPhaseById

```lua
Game.SetPrefabPhaseById()
```

C++: `int SetPrefabPhaseById (IFunctionHandler* pH , ScriptHandle entityId , const char * categoryName , int id )`

docs: y · retail: confirmed (runtime dump)

### SetUIHudMessages

```lua
Game.SetUIHudMessages()
```

C++: `void SetUIHudMessages (framework::I_UIHudMessages* uiHudMessages )`

docs: y · retail: unconfirmed

### SetWantedLevel

```lua
Game.SetWantedLevel()
```

C++: `int SetWantedLevel (IFunctionHandler * pH , int level )`

docs: y · retail: unconfirmed

### ShadowplayStartStop

```lua
Game.ShadowplayStartStop()
```

C++: `int CScriptBindGame::ShadowplayStartStop (IFunctionHandler* pH )`

Sends [Alt] + [F9] to start/stop the Shadowplay capturing Only for Windows

docs: y · retail: confirmed (binary, runtime dump)

### ShowCaptionObjectMessage

```lua
Game.ShowCaptionObjectMessage()
```

C++: `int ShowCaptionObjectMessage (IFunctionHandler * pH , const char * captionObjectName )`

docs: y · retail: confirmed (vanilla×1 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/WH/Others/CaptionObject.lua`))

### ShowItemsTransfer

```lua
Game.ShowItemsTransfer()
```

C++: `int ShowItemsTransfer (IFunctionHandler * pH , string classId , int amount )`

Displays UI message informing about item transfered into/from players inventory

docs: y · retail: confirmed (runtime dump, vanilla×10 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/WH/Triggers/IndulgenceBoxTrigger.lua`))

### ShowNotification

```lua
Game.ShowNotification()
```

C++: `int ShowNotification (IFunctionHandler * pH , const char * message )`

docs: y · retail: confirmed (binary, runtime dump)

### ShowOverlayTutorial

```lua
Game.ShowOverlayTutorial(text)
```

C++: `int ShowOverlayTutorial (IFunctionHandler * pH , const char * text )`

Show tutorial in overlay window, parameter is name of tutorial

docs: y · retail: confirmed (binary, runtime dump)

### ShowStatCheckResult

```lua
Game.ShowStatCheckResult(stat, result)
```

C++: `int ShowStatCheckResult (IFunctionHandler * pH , int stat , bool result )`

Show something like "Persuade: succeeded". Stat: shortcut name of stat (eg. "spc"), result: true=succeeded, false=failed.

docs: y · retail: confirmed (runtime dump, vanilla×6 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Utils/DialogUtils.lua`))

### ShowTutorial

```lua
Game.ShowTutorial(name)
```

Shows tutorial message. Other tutorial parameters are specified in the game table.

| Param | Description |
|---|---|
| const char * name | id (name) of the tutorial from the tutorials.xml table. |

docs: y · retail: confirmed (binary, runtime dump, vanilla×9 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/actor/player.lua`))

> **Verified note:** Documented with a single string-ish signature, but `hud.xml` defines it with 6 parameters (Id, Text, Duration, InDialogue, Priority, Layout) and at least one community mod calls it with 8 (adding ActionHintEnable, OverlayLink). Treat the documented arity as incomplete. -- kcd2/ui-scaleform.md#other-lua-ui-entry-points (verified in game)

### ShowTutorialWithCodex

```lua
Game.ShowTutorialWithCodex(text, codexPerkId, timeout = 0, syncWithDialogue = false, forceTutorial = false)
```

Shows tutorial message for set time.

| Param | Description |
|---|---|
| const char * text | text of tutorial. |
| codexPerkId | This codex entry will be unlocked on player and action hint "press N to see this in codex" will be displayed. |
| timeout | time to show tutorial, larger than 0, default is 0 - never hidden. |

docs: y · retail: unconfirmed

### SpawnPrefab

```lua
Game.SpawnPrefab()
```

C++: `int SpawnPrefab (IFunctionHandler* pH , ScriptHandle entityId , const char * prefabTemplateId , uint32 nMaxSpawn )`

docs: y · retail: confirmed (binary, runtime dump, vanilla×1 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/Others/RuntimePrefab.lua`), mod×7)

### UnblockInfoText

```lua
Game.UnblockInfoText(category)
```

C++: `int UnblockInfoText (IFunctionHandler * pH , int categoryRuntimeId )`

Reverts effect of Game.BlockInfoText(category).

docs: y · retail: unconfirmed

### WarpTime

```lua
Game.WarpTime(float wantedSpeed, float duration, float fadeIn, float fadeOut)
```

Time effects ============================================= Syntax: Actor.WarpTime(float wantedSpeed, float duration)

Slowdown/speedup global time for given time period

| Param | Description |
|---|---|
| float wantedSpeed | target speed of global time |
| float duration | duration of the time effect |
| float fadeIn | fade in of the time effect |
| float fadeOut | fade out of the time effect |

docs: y · retail: unconfirmed

## Undocumented (present in retail, not in official docs)

### HideCurrentTutorial

`Game.HideCurrentTutorial(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (binary, runtime dump, vanilla×2 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/actor/player.lua`))
