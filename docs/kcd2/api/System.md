# System

C++ class(es): `CScriptBindSystem`, `CScriptBind_System`, `C_ScriptBindEntityModule`
Reached from Lua as `System.FunctionName(...)`.
130 documented function(s); 5 additional undocumented function(s) found in retail/runtime.

## Functions

### ActivateLight

```lua
System.ActivateLight(name, activate)
```

C++: `int ActivateLight (IFunctionHandler * pH )`

NOT SUPPORTED ANYMORE.

docs: y · retail: confirmed (binary, runtime dump, vanilla×30)

### ActivatePortal

```lua
System.ActivatePortal(vPos, bActivate, nID)
```

Activates/deactivates a portal.

| Param | Description |
|---|---|
| vPos | Position vector. |
| bActivate | True to activate the portal, false to deactivate. |
| nID | Entity identifier. |

docs: y · retail: confirmed (binary, runtime dump, vanilla×4 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/Doors/AnimDoor.lua`))

### AddCCommand

```lua
System.AddCCommand(sCCommandName, sCommand, sHelp)
```

Adds a C command to the system.

| Param | Description |
|---|---|
| sCCommandName | C command name. |
| sCommand | Command string. |
| sHelp | Help for the command usage. |

docs: y · retail: confirmed (binary, runtime dump, mod×27)

### ApplicationTest

```lua
System.ApplicationTest(pszParam)
```

Test the application with the specified parameters.

| Param | Description |
|---|---|
| pszParam | Parameters. |

docs: y · retail: confirmed (binary, runtime dump)

### ApplyForceToEnvironment

```lua
System.ApplyForceToEnvironment(pos, force, radius)
```

Applies a force to the environment.

| Param | Description |
|---|---|
| pos | Position of the force. |
| force | Strength of the force. |
| radius | Area where the force has effects. |

docs: y · retail: confirmed (binary, runtime dump)

### Break

```lua
System.Break()
```

C++: `int Break (IFunctionHandler * pH )`

Breaks the application with a fatal error message.

docs: y · retail: confirmed (binary, runtime dump)

### BrowseURL

```lua
System.BrowseURL(szURL)
```

Browses a URL address.

| Param | Description |
|---|---|
| szURL | URL string. |

docs: y · retail: confirmed (binary, runtime dump)

### CheckHeapValid

```lua
System.CheckHeapValid(name)
```

Checks the heap validity.

| Param | Description |
|---|---|
| name | Name string. |

docs: y · retail: confirmed (binary, runtime dump)

### ClearConsole

```lua
System.ClearConsole()
```

C++: `int ClearConsole (IFunctionHandler * pH )`

Clears the console.

Clear the console

docs: y · retail: confirmed (binary, runtime dump)

### ClearKeyState

```lua
System.ClearKeyState()
```

C++: `int ClearKeyState (IFunctionHandler* pH )`

Clear the key state.

docs: y · retail: confirmed (binary, runtime dump)

### CreateDownload

```lua
System.CreateDownload()
```

C++: `int CreateDownload (IFunctionHandler * pH )`

Creates a download object @return download object just created

docs: y · retail: confirmed (runtime dump)

### DebugStats

```lua
System.DebugStats(cp)
```

C++: `int DebugStats (IFunctionHandler * pH )`

docs: y · retail: confirmed (binary, runtime dump)

### DeformTerrain

```lua
System.DeformTerrain()
```

C++: `int DeformTerrain (IFunctionHandler * pH )`

Deforms the terrain.

docs: y · retail: confirmed (runtime dump)

### DeformTerrainUsingMat

```lua
System.DeformTerrainUsingMat()
```

C++: `int DeformTerrainUsingMat (IFunctionHandler * pH )`

Deforms the terrain using material.

docs: y · retail: confirmed (runtime dump)

### Draw2DLine

```lua
System.Draw2DLine(p1x, p1y, p2x, p2y, r, g, b, alpha)
```

Draws a 2D line.

| Param | Description |
|---|---|
| p1x | X value of the start point of the line. |
| p1y | Y value of the start point of the line. |
| p2x | X value of the end point of the line. |
| p2y | Y value of the end point of the line. |
| r | Red component for the label color. Default is 1. |
| g | Green component for the label color. Default is 1. |
| b | Blue component for the label color. Default is 1. |
| alpha | Alpha component for the label color. Default is 1. |

docs: y · retail: confirmed (binary, runtime dump, mod×8)

> **Verified note:** Earlier testing concluded this was unusable in any coordinate space; later measurement showed it takes normalised 0..1 coordinates, not pixels -- pixel values render as a huge white shape flying off into the world. -- kcd2/ui-scaleform.md#immediate-mode-drawing (verified in game)

### DrawLabel

```lua
System.DrawLabel(vPos, fSize, text [, r [, g [, b [, alpha]]]])
```

Draws a label with the specified parameter.

| Param | Description |
|---|---|
| vPos | Position vector. |
| fSize | Size for the label. |
| text | Text of the label. |
| r | Red component for the label colour. Default is 1. |
| g | Green component for the label colour. Default is 1. |
| b | Blue component for the label colour. Default is 1. |
| alpha | Alpha component for the label colour. Default is 1. |

docs: y · retail: confirmed (binary, runtime dump, vanilla×1 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/Others/Comment.lua`), mod×1)

### DrawLine

```lua
System.DrawLine(p1, p2, r, g, b, alpha)
```

Draws a line.

| Param | Description |
|---|---|
| p1 | Start position of the line. |
| p2 | End position of the line. |
| r | Red component for the label color. Default is 1. |
| g | Green component for the label color. Default is 1. |
| b | Blue component for the label color. Default is 1. |
| alpha | Alpha component for the label color. Default is 1. |

docs: y · retail: confirmed (binary, runtime dump, vanilla×2 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/WH/Others/BirdsTakeoff.lua`), mod×1)

### DrawRectShader

```lua
System.DrawRectShader(const char *pszShaderName, float x, float y, float w, float h, float r, float g, float b, float a)
```

Use the shader to draw a rectangular.

| Param | Description |
|---|---|
| pszShaderName | Shader name. |
| x | Rectangular x position. |
| y | Rectangular y position. |
| w | Rectangular width. |
| h | Rectangular height. |

docs: y · retail: unconfirmed

### DrawText

**Retail:** `System.DrawText(x, y, text, size, r, g, b, a)`

```lua
System.DrawText(x, y, text, font, size, p2y, r, g, b, alpha)
```

Draws a text.

| Param | Description |
|---|---|
| x | X position for the text. |
| y | Y position for the text. |
| text | Text to be displayed. |
| font | Font name. |
| size | Text size. |
| r | Red component for the label color. Default is 1. |
| g | Green component for the label color. Default is 1. |
| b | Blue component for the label color. Default is 1. |
| alpha | Alpha component for the label color. Default is 1. |

docs: y · retail: confirmed (binary, runtime dump, vanilla×2 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/WH/Others/CrimeDebugger.lua`), mod×14)

> **Verified note:** System.DrawText(x, y, text, size, r, g, b, a) -- kcd2/ui-scaleform.md#immediate-mode-drawing (verified in game)

### DrawTriStrip

```lua
System.DrawTriStrip(handle, nMode, vtxs, r, g, b, alpha)
```

Draws a triangle strip.

| Param | Description |
|---|---|
| handle | . |
| nMode | . |
| vtx | . |
| r | Red component for the label color. Default is 1. |
| g | Green component for the label color. Default is 1. |
| b | Blue component for the label color. Default is 1. |
| alpha | Alpha component for the label color. Default is 1. |

docs: y · retail: unconfirmed

> **Verified note:** Absent in retail -- calling it has no effect. No filled-polygon drawing is available via System's immediate-mode draw calls. -- kcd2/ui-scaleform.md#immediate-mode-drawing (verified in game)

### DumpMemoryCoverage

```lua
System.DumpMemoryCoverage(bUseKB)
```

C++: `int DumpMemoryCoverage (IFunctionHandler * pH )`

Dumps memory coverage.

docs: y · retail: confirmed (binary, runtime dump)

### DumpMemStats

```lua
System.DumpMemStats(bUseKB)
```

Dumps memory statistics.

| Param | Description |
|---|---|
| bUseKB | True to use KB, false otherwise. |

docs: y · retail: confirmed (binary, runtime dump)

### DumpMMStats

```lua
System.DumpMMStats()
```

C++: `int DumpMMStats (IFunctionHandler * pH )`

Dumps the MM statistics.

docs: y · retail: confirmed (binary, runtime dump)

### DumpWinHeaps

```lua
System.DumpWinHeaps()
```

C++: `int DumpWinHeaps (IFunctionHandler * pH )`

Dumps windows heaps.

docs: y · retail: confirmed (binary, runtime dump)

### EnableHeatVision

```lua
System.EnableHeatVision()
```

C++: `int EnableHeatVision (IFunctionHandler * pH )`

Is not supported anymore.

docs: y · retail: confirmed (binary, runtime dump)

### EnableLayer

```lua
System.EnableLayer(sLayerName, enable)
```

C++: `int EnableLayer (IFunctionHandler * pH , const char * sLayerName , bool enable )`

Enable/Disable entity layer by name/path "Parent.Child.Child"

docs: y · retail: unconfirmed

### EnableMainView

```lua
System.EnableMainView()
```

C++: `int EnableMainView (IFunctionHandler * pH )`

Feature unimplemented.

docs: y · retail: confirmed (binary, runtime dump)

### EnableOceanRendering

```lua
System.EnableOceanRendering()
```

Enables/disables ocean rendering.

int CScriptBindSystem::IndoorSoundAllowed(IFunctionHandler * pH) { SCRIPT_CHECK_PARAMETERS(2); CScriptVector pVecOrigin(m_pSS,false); CScriptVector pVecDestination(m_pSS,false);

IGraph *pGraph = gEnv->pAISystem->GetNodeGraph();

Vec3 start = pVecOrigin.Get(); Vec3 end = pVecDestination.Get();

if ((start.x 2000.f)||(start.y 2000.f)) { m_pLog->LogError("[CRASHWARNING] Unnaturally high value placed for sound detection"); return pH->EndFunction(true); // there is no sound occlusion in outdoor }

if ((end.x 2000.f)||(end.y 2000.f)) { m_pLog->LogError("[CRASHWARNING] Unnaturally high value placed for sound detection"); return pH->EndFunction(true); // there is no sound occlusion in outdoor }

GraphNode *pStart = pGraph->GetEnclosing(pVecOrigin.Get());

if (pStart->nBuildingID EndFunction(true); // there is no sound occlusion in outdoor

GraphNode *pEnd = pGraph->GetEnclosing(pVecDestination.Get());

if (pStart->nBuildingID!=pEnd->nBuildingID) return pH->EndFunction(false); // if in 2 different buildings we cannot hear the sound for sure

// make the real indoor sound occlusion check (doors, sectors etc.) return (gEnv->p3DEngine->IsVisAreasConnected(pStart->pArea,pEnd->pArea,1,false));

//IIndoorBase *pIndoor = m_p3DEngine->GetBuildingManager(); //if (pIndoor) { // make the real indoor sound occlusion check (doors, sectors etc.) return pH->EndFunction(pIndoor->IsSoundPotentiallyHearable(pStart->nBuildingID,pStart->nSector,pEnd->nSector)); //}

return pH->EndFunction(true);

| Param | Description |
|---|---|
| bOcean | True to activate the ocean rendering, false to deactivate it. |

docs: y · retail: confirmed (binary, runtime dump)

### EnumAAFormats

```lua
System.EnumAAFormats(m_Width, m_Height, m_BPP)
```

C++: `int EnumAAFormats (IFunctionHandler * pH )`

Enumerates the AA formats.

docs: y · retail: confirmed (binary, runtime dump)

### EnumDisplayFormats

```lua
System.EnumDisplayFormats()
```

C++: `int EnumDisplayFormats (IFunctionHandler * pH )`

Enumerates display formats.

docs: y · retail: confirmed (binary, runtime dump)

### Error

```lua
System.Error(sText)
```

Shows a message text with the error severity.

| Param | Description |
|---|---|
| sText | Text to be logged. |

docs: y · retail: confirmed (binary, runtime dump)

### ExecuteCommand

```lua
System.ExecuteCommand(szCmd)
```

Executes a command.

| Param | Description |
|---|---|
| szCmd | Command string. |

docs: y · retail: confirmed (binary, runtime dump, vanilla×14 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Debug/CombatDebug.lua`), mod×70)

### GetArchetypeProperties

```lua
System.GetArchetypeProperties()
```

C++: `int GetArchetypeProperties (IFunctionHandler* pH , char const * archetype )`

Returns property table for selected archetype.

docs: y · retail: confirmed (binary, runtime dump, vanilla×2 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/WH/Torch/Lamp.lua`))

### GetConfigSpec

```lua
System.GetConfigSpec()
```

C++: `int GetConfigSpec (IFunctionHandler * pH )`

Gets the config specification.

docs: y · retail: confirmed (binary, runtime dump)

### GetCPUQuality

```lua
System.GetCPUQuality()
```

C++: `int GetCPUQuality (IFunctionHandler * pH )`

CW: added for script based system analysis Syntax: System.GetCPUQuality()

Gets the CPU quality.

docs: y · retail: unconfirmed

### GetCurrAsyncTime

```lua
System.GetCurrAsyncTime()
```

C++: `int GetCurrAsyncTime (IFunctionHandler * pH )`

Gets the current asynchronous time.

docs: y · retail: confirmed (binary, runtime dump, vanilla×2 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/Physics/AnimObject.lua`), mod×3)

### GetCurrTime

```lua
System.GetCurrTime()
```

C++: `int GetCurrTime (IFunctionHandler * pH )`

Gets the current time.

docs: y · retail: confirmed (binary, runtime dump, vanilla×2 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/Physics/AnimObject.lua`), mod×101)

### GetCVar

```lua
System.GetCVar(sCVarName)
```

Gets the value of a CVariable.

| Param | Description |
|---|---|
| sCVarName | Name of the variable. |

docs: y · retail: confirmed (binary, runtime dump, vanilla×9 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Debug/CombatDebug.lua`), mod×27)

### GetEntities

```lua
System.GetEntities(center, radius)
```

Gets all the entities contained in the specific area of the level.

return a all entities currently present in the level @return a table filled with all entities currently present in the level

| Param | Description |
|---|---|
| center | Center position vector for the area where to get entities. |
| radius | Radius of the area. |

docs: y · retail: confirmed (binary, runtime dump, vanilla×1 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Utils/EntityUtils.lua`))

### GetEntitiesByClass

```lua
System.GetEntitiesByClass(EntityClass)
```

Gets all the entities of the specified class.

return a all entities for a specified entity class @return a table filled with all entities of a specified entity class

| Param | Description |
|---|---|
| const char* EntityClass | Entity class name. |

docs: y · retail: confirmed (binary, runtime dump, mod×44)

### GetEntitiesInSphere

```lua
System.GetEntitiesInSphere(centre, radius)
```

Gets all the entities contained into the specified sphere.

return a all entities for a specified entity class @return a table filled with all entities of a specified entity class in a radius

| Param | Description |
|---|---|
| float radius | Radius of the sphere. |
| centre | Centre position vector for the sphere where to look at entities. |

docs: y · retail: confirmed (binary, runtime dump, mod×6)

### GetEntitiesInSphereByClass

```lua
System.GetEntitiesInSphereByClass(centre, radius, EntityClass)
```

Gets all the entities contained into the specified sphere for the specific class name.

return a all entities for a specified entity class @return a table filled with all entities of a specified entity class in a radius

| Param | Description |
|---|---|
| float radius | Radius of the sphere. |
| const char* EntityClass | Entity class name. |
| centre | Centre position vector for the sphere where to look at entities. |

docs: y · retail: confirmed (binary, runtime dump, mod×8)

### GetEntity

```lua
System.GetEntity(entityId)
```

Gets an entity from its ID.

Get an entity by id @param nID the entity id

| Param | Description |
|---|---|
| entityId | Entity identifier. |

docs: y · retail: confirmed (binary, runtime dump, vanilla×33 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Debug/CombatDebug.lua`), mod×82)

### GetEntityByGUID

```lua
System.GetEntityByGUID(SmartScriptTable dataTable)
```

Retrieve entity table for the first entity withe the given EntityGUID

| Param | Description |
|---|---|
| eGUID | table of the guid. |

docs: y · retail: confirmed (binary, runtime dump)

### GetEntityByName

```lua
System.GetEntityByName(sEntityName)
```

Retrieve entity table for the first entity with specified name. ! If multiple entities with same name exist, first one found is returned. !

| Param | Description |
|---|---|
| const char* sEntityName | Name of the entity to search. |

docs: y · retail: confirmed (binary, runtime dump, vanilla×42 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Debug/CombatDebug.lua`), mod×49)

### GetEntityByTextGUID

```lua
System.GetEntityByTextGUID(entityGuid)
```

Retrieve entity with the given entityGUID

| Param | Description |
|---|---|
| entityGuid | hexadecimal guid (e.g. 0x1235489765) |

docs: y · retail: confirmed (binary, runtime dump)

### GetEntityClass

```lua
System.GetEntityClass(entityId)
```

Gets an entity class from its ID.

| Param | Description |
|---|---|
| entityId | Entity identifier. |

docs: y · retail: confirmed (binary, runtime dump)

### GetEntityIdByName

```lua
System.GetEntityIdByName(sEntityName)
```

Retrieve entity Id for the first entity with specified name. ! If multiple entities with same name exist, first one found is returned. !

| Param | Description |
|---|---|
| const char* sEntityName | Name of the entity to search. |

docs: y · retail: confirmed (binary, runtime dump)

### GetFrameID

```lua
System.GetFrameID()
```

C++: `int GetFrameID (IFunctionHandler * pH )`

Gets the frame identifier.

docs: y · retail: confirmed (binary, runtime dump, mod×6)

### GetFrameRate

```lua
System.GetFrameRate()
```

C++: `int GetFrameRate (IFunctionHandler * pH )`

Gets the frame rate.

docs: y · retail: unconfirmed

### GetFrameTime

```lua
System.GetFrameTime()
```

C++: `int GetFrameTime (IFunctionHandler * pH )`

Gets the frame time.

docs: y · retail: confirmed (binary, runtime dump)

### GetFrameTimeUI

```lua
System.GetFrameTimeUI()
```

C++: `int GetFrameTimeUI (IFunctionHandler * pH )`

Gets the UI frame time.

docs: y · retail: unconfirmed

### GetGPUQuality

```lua
System.GetGPUQuality()
```

C++: `int GetGPUQuality (IFunctionHandler * pH )`

Gets the GPU quality.

docs: y · retail: unconfirmed

### GetHDRDynamicMultiplier

```lua
System.GetHDRDynamicMultiplier()
```

C++: `int GetHDRDynamicMultiplier (IFunctionHandler * pH )`

Gets hte HDR dynamic multiplier.

docs: y · retail: unconfirmed

### GetLocalOSTime

```lua
System.GetLocalOSTime()
```

C++: `int GetLocalOSTime (IFunctionHandler * pH )`

Gets the local operating system time.

docs: y · retail: confirmed (binary, runtime dump)

### GetMemoryUsage

```lua
System.GetMemoryUsage()
```

C++: `virtual void GetMemoryUsage (ICrySizer* pSizer ) const`

This is GetMemoryUsage, a member of class CScriptBind_System.

docs: y · retail: unconfirmed

### GetNearestEntityByClass

```lua
System.GetNearestEntityByClass(centre, radius, className)
```

Gets the nearest entity with the specified class.

| Param | Description |
|---|---|
| float radius | Radius of the sphere. |
| const char * className | Entity class name. |
| centre | Centre position vector for the area where to look at entities. |

docs: y · retail: confirmed (binary, runtime dump)

### GetNearestEntityByName

```lua
System.GetNearestEntityByName(sEntityName)
```

Retrieve entity table for the entity with specified name. ! If multiple entities with same name exist, the one neartest to camera is returned. !

| Param | Description |
|---|---|
| const char* sEntityName | Name of the entity to search. |

docs: y · retail: confirmed (binary, runtime dump, vanilla×1 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Debug/Quick.lua`))

### GetOutdoorAmbientColor

```lua
System.GetOutdoorAmbientColor(v3Color)
```

Sets the outdoor ambient color.

| Param | Description |
|---|---|
| v3Color | Outdoor ambient color value. |

docs: y · retail: confirmed (binary, runtime dump)

### GetPhysicalEntitiesInBox

```lua
System.GetPhysicalEntitiesInBox(centre, radius)
```

Gets all the entities contained into the specified area.

return all entities contained in a certain radius @param oVec center of the sphere @param fRadius length of the radius @return a table filled with all entities contained in the specified radius

| Param | Description |
|---|---|
| float radius | Radius of the sphere. |
| centre | Centre position vector for the area where to look at entities. |

docs: y · retail: confirmed (binary, runtime dump, mod×4)

### GetPhysicalEntitiesInBoxByClass

```lua
System.GetPhysicalEntitiesInBoxByClass(centre, radius, className)
```

Gets all the entities contained into the specified area for the specific class name.

| Param | Description |
|---|---|
| float radius | Radius of the sphere. |
| const char * className | Entity class name. |
| centre | Centre position vector for the area where to look at entities. |

docs: y · retail: confirmed (binary, runtime dump, mod×32)

### GetPostProcessFxParam

```lua
System.GetPostProcessFxParam(pszEffectParam, value)
```

Gets a post processing effect parameter value.

| Param | Description |
|---|---|
| pszEffectParam | Parameter for the post processing effect. |
| value | Value for the parameter. |

docs: y · retail: confirmed (binary, runtime dump)

### GetRealFrameTime

```lua
System.GetRealFrameTime()
```

C++: `int GetRealFrameTime (IFunctionHandler * pH )`

Gets the real frame time.

docs: y · retail: unconfirmed

### GetScreenFx

```lua
System.GetScreenFx(pszEffectParam, value)
```

Gets a post processing effect parameter value.

| Param | Description |
|---|---|
| pszEffectParam | Parameter for the post processing effect. |
| value | Value for the parameter. |

docs: y · retail: confirmed (runtime dump)

### GetSkyColor

```lua
System.GetSkyColor()
```

C++: `int GetSkyColor (IFunctionHandler * pH )`

Retrieve color of the sky (outdoor ambient color).

Returns: Sky Color as an {x,y,z} vector (x=r,y=g,z=b).

docs: y · retail: confirmed (binary, runtime dump, vanilla×1 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/Render/Lightning.lua`))

### GetSunColor

```lua
System.GetSunColor()
```

C++: `int GetSunColor (IFunctionHandler * pH )`

Retrieve color of the sun outdoors.

Returns: Sun Color as an {x,y,z} vector (x=r,y=g,z=b).

docs: y · retail: confirmed (binary, runtime dump)

### GetSurfaceTypeIdByName

```lua
System.GetSurfaceTypeIdByName(surfaceName)
```

Gets the surface type identifier by its name.

| Param | Description |
|---|---|
| const char* surfaceName | Surface name. |

docs: y · retail: confirmed (binary, runtime dump)

### GetSurfaceTypeNameById

```lua
System.GetSurfaceTypeNameById(surfaceId)
```

Gets the surface type name by its identifier.

| Param | Description |
|---|---|
| int surfaceId | Surface identifier. |

docs: y · retail: confirmed (runtime dump, mod×6)

### GetSystemMem

```lua
System.GetSystemMem()
```

C++: `int GetSystemMem (IFunctionHandler * pH )`

Gets the amount of the memory for the system.

docs: y · retail: confirmed (binary, runtime dump)

### GetTerrainElevation

```lua
System.GetTerrainElevation(v3Pos)
```

Gets the terrain elevation of the specified position.

| Param | Description |
|---|---|
| v3Pos | Position of the terraint to be checked. |

docs: y · retail: confirmed (binary, runtime dump, mod×5)

### GetUsedMemory

```lua
System.GetUsedMemory()
```

C++: `int GetUsedMemory (IFunctionHandler * pH )`

Gets the used memory

docs: y · retail: unconfirmed

### GetUserName

```lua
System.GetUserName()
```

C++: `int GetUserName (IFunctionHandler * pH )`

Gets the username on this machine.

docs: y · retail: confirmed (binary, runtime dump)

### GetVideoMem

```lua
System.GetVideoMem()
```

C++: `int GetVideoMem (IFunctionHandler * pH )`

Gets the amount of the video memory for the system.

docs: y · retail: unconfirmed

### GetViewCameraAngles

```lua
System.GetViewCameraAngles()
```

C++: `int GetViewCameraAngles (IFunctionHandler * pH )`

Gets the view camera angles.

docs: y · retail: confirmed (binary, runtime dump)

### GetViewCameraDir

```lua
System.GetViewCameraDir()
```

C++: `int GetViewCameraDir (IFunctionHandler * pH )`

Gets the view camera direction.

docs: y · retail: confirmed (binary, runtime dump, vanilla×2 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/Render/Lightning.lua`), mod×4)

### GetViewCameraFov

```lua
System.GetViewCameraFov()
```

C++: `int GetViewCameraFov (IFunctionHandler * pH )`

Gets the view camera fov.

docs: y · retail: confirmed (binary, runtime dump, vanilla×1 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/Others/Comment.lua`))

### GetViewCameraPos

```lua
System.GetViewCameraPos()
```

C++: `int GetViewCameraPos (IFunctionHandler * pH )`

Gets the view camera position.

docs: y · retail: confirmed (binary, runtime dump, vanilla×2 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/Others/Comment.lua`), mod×4)

### GetViewCameraUpDir

```lua
System.GetViewCameraUpDir()
```

C++: `int GetViewCameraUpDir (IFunctionHandler* pH )`

Gets the view camera up-direction.

docs: y · retail: confirmed (binary, runtime dump, vanilla×1 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/Others/Comment.lua`))

### GetViewport

```lua
System.GetViewport()
```

C++: `int GetViewport (IFunctionHandler* pH )`

Returns table with viewport params: x, y, width, height

docs: y · retail: confirmed (binary, runtime dump, vanilla×1 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/WH/Others/CrimeDebugger.lua`), mod×5)

### IsDevModeEnable

```lua
System.IsDevModeEnable()
```

C++: `int IsDevModeEnable (IFunctionHandler* pH )`

Checks if game is running in dev mode (cheat mode) ! to check if we are allowed to enable certain scripts ! function facilities (god mode, fly mode etc.).

docs: y · retail: confirmed (binary, runtime dump, vanilla×1 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/Others/Comment.lua`), mod×2)

### IsEditing

```lua
System.IsEditing()
```

C++: `int IsEditing (IFunctionHandler * pH )`

Checks if the system is in pure editor mode, i.e. not editor game mode.

docs: y · retail: confirmed (binary, runtime dump, vanilla×3 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/Others/Comment.lua`))

### IsEditor

```lua
System.IsEditor()
```

C++: `int IsEditor (IFunctionHandler * pH )`

Checks if the system is the editor.

docs: y · retail: confirmed (binary, runtime dump, vanilla×21 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/AI/pathfindProperties.lua`))

### IsEditorGameMode

```lua
System.IsEditorGameMode()
```

C++: `int IsEditorGameMode (IFunctionHandler * pH )`

Checks if the system is the editor and in-game (CTRL+G).

docs: y · retail: unconfirmed

### IsFileExist

```lua
System.IsFileExist(pszFileName)
```

Return 1 if the requested file exists.

| Param | Description |
|---|---|
| const char* sFileName | File name, including its path. |

docs: y · retail: confirmed (binary, runtime dump)

### IsHDRSupported

```lua
System.IsHDRSupported()
```

C++: `int IsHDRSupported (IFunctionHandler * pH )`

Checks if the HDR is supported.

docs: y · retail: confirmed (binary, runtime dump)

### IsMultiplayer

```lua
System.IsMultiplayer()
```

C++: `int IsMultiplayer (IFunctionHandler * pH )`

Checks if the game is multiplayer.

docs: y · retail: confirmed (runtime dump, vanilla×8 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/Others/SpawnPoint.lua`))

### IsPointIndoors

```lua
System.IsPointIndoors(vPos)
```

Checks if a point is indoors.

| Param | Description |
|---|---|
| vPos | Position vector. |

docs: y · retail: confirmed (binary, runtime dump)

> **Verified note:** Always returns false in retail -- KCD2's levels contain zero VisAreas/Portals (the CryEngine feature this call tests). Use the `interior` area-label pattern instead (BT `IsInsideAreaWithLabel`, Skald `AreaLabelTrigger`, or `XGenAIModule.IsPointInAreaWithLabelWUID`). -- kcd2/world-and-physics.md#interiors-and-area-labels (verified in game)

### IsPointVisible

```lua
System.IsPointVisible(point)
```

Checks if the specified point is visible.

| Param | Description |
|---|---|
| Vec3 point | Point vector. |

docs: y · retail: confirmed (binary, runtime dump)

### IsPS20Supported

```lua
System.IsPS20Supported()
```

C++: `int IsPS20Supported (IFunctionHandler * pH )`

Checks if the PS20 is supported.

docs: y · retail: unconfirmed

### IsValidMapPos

```lua
System.IsValidMapPos(v)
```

Checks if the position is a valid map position.

int CScriptBindSystem::ActivateMainLight(IFunctionHandler *pH) { SCRIPT_CHECK_PARAMETERS(2); bool bActive; CScriptVector oVec(m_pSS); if(pH->GetParam(1,*oVec)) { pH->GetParam(2, bActive); m_p3DEngine->GetBuildingManager()->ActivateMainLight(oVec.Get(), bActive); } return pH->EndFunction(); }

int CScriptBindSystem::SetSkyBox(IFunctionHandler *pH) { SCRIPT_CHECK_PARAMETERS(3); const char *pszShaderName; float fBlendTime; bool bUseWorldBrAndColor; pH->GetParam(1, pszShaderName); pH->GetParam(2, fBlendTime); pH->GetParam(3, bUseWorldBrAndColor); m_p3DEngine->SetSkyBox(pszShaderName);// not supported now: fBlendTime, bUseWorldBrAndColor); return pH->EndFunction();

| Param | Description |
|---|---|
| v | Position vector. |

docs: y · retail: confirmed (binary, runtime dump)

### LoadFont

```lua
System.LoadFont(pszName)
```

Loads a font.

Loads a font and makes it available for future-selection @param name of font-xml-file (no suffix)

| Param | Description |
|---|---|
| pszName | Font name. |

docs: y · retail: confirmed (binary, runtime dump)

### LoadLocalizationXml

```lua
System.LoadLocalizationXml(filename)
```

C++: `int LoadLocalizationXml (IFunctionHandler * pH , const char * filename )`

Loads Excel exported xml file with text and dialog localization data.

docs: y · retail: confirmed (binary, runtime dump)

### LoadTextFile

```lua
System.LoadTextFile(filename)
```

C++: `int LoadTextFile (IFunctionHandler* pH , const char * fileName )`

Loads text file to a string.

docs: y · retail: confirmed (binary, runtime dump, vanilla×1 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Utils/XML/xmlDocument.lua`))

### LoadTimeOfDayFile

```lua
System.LoadTimeOfDayFile(filename)
```

C++: `int LoadTimeOfDayFile (IFunctionHandler * pH , const char * fileName )`

Loads a TOD file for the timeofday system

docs: y · retail: unconfirmed

### Log

```lua
System.Log(sText)
```

Logs a message.

Write a message into the log file and the console @param String to write @see stuff

| Param | Description |
|---|---|
| sText | Text to be logged. |

docs: y · retail: confirmed (runtime dump, vanilla×122 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Debug/DebugUtils.lua`))

### LogAlways

```lua
System.LogAlways(sText)
```

Logs important data that must be printed regardless verbosity.

log even with log verbosity 0 - without @param String to write

| Param | Description |
|---|---|
| sText | Text to be logged. |

docs: y · retail: confirmed (binary, runtime dump, mod×902)

### LogToConsole

```lua
System.LogToConsole(sText)
```

Logs a message to the console.

Write a string to the console @param String to write @see CScriptBind_System::Log

| Param | Description |
|---|---|
| sText | Text to be logged. |

docs: y · retail: confirmed (binary, runtime dump, vanilla×13 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/Others/RigidBody.lua`))

### PrepareEntityFromPool

```lua
System.PrepareEntityFromPool(entityId)
```

Prepares the given bookmarked entity from the pool, bringing it into existence.

Entity pool management @param nID the entity id @param bPrepareNow (optional) whether the entity shall get prepared immediately, rather than enqueuing a request if another entity is already being prepared

| Param | Description |
|---|---|
| entityId | Entity identifier. |
| bPrepareNow | (optional) Specifies whether the pooled entity shall be prepared immediately rather than queuing a request in case there is a preparation already in progress. |

docs: y · retail: confirmed (binary, runtime dump)

### ProjectToScreen

```lua
System.ProjectToScreen(vec)
```

Projects to the screen (not guaranteed to work if used outside Renderer).

9/16/2010 evgeny] ProjectToScreen is not guaranteed to work if used outside Renderer

| Param | Description |
|---|---|
| Vec3 vec | Position vector. |

docs: y · retail: confirmed (binary, runtime dump, mod×2)

### Quit

```lua
System.Quit()
```

C++: `int Quit (IFunctionHandler * pH )`

Quits the program.

docs: y · retail: confirmed (binary, runtime dump)

### QuitInNSeconds

```lua
System.QuitInNSeconds(fInNSeconds)
```

Quits the application in the specified number of seconds.

| Param | Description |
|---|---|
| fInNSeconds | Number of seconds before quitting. |

docs: y · retail: confirmed (binary, runtime dump)

### RayTraceCheck

```lua
System.RayTraceCheck(src, dst, skipId1, skipId2)
```

C++: `int RayTraceCheck (IFunctionHandler * pH )`

docs: y · retail: confirmed (binary, runtime dump)

### RayWorldIntersection

```lua
System.RayWorldIntersection(vPos, vDir, nMaxHits, iEntTypes)
```

Shots rays into the world.

| Param | Description |
|---|---|
| vPos | Position vector. |
| vDir | Direction vector. |
| nMaxHits | Maximum number of hits. |
| iEntTypes | . |

docs: y · retail: confirmed (binary, runtime dump)

### RemoveEntity

```lua
System.RemoveEntity(entityId)
```

Removes the specified entity.

| Param | Description |
|---|---|
| ScriptHandle entityId | Entity identifier. |

docs: y · retail: confirmed (runtime dump, vanilla×4 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/EntityCommon.lua`), mod×155)

### ResetPoolEntity

```lua
System.ResetPoolEntity(entityId)
```

Resets the entity's bookmarked, which frees memory.

| Param | Description |
|---|---|
| entityId | Entity identifier. |

docs: y · retail: confirmed (binary, runtime dump)

### ReturnEntityToPool

```lua
System.ReturnEntityToPool(entityId)
```

Returns the bookmarked entity to the pool, destroying it.

| Param | Description |
|---|---|
| entityId | Entity identifier. |

docs: y · retail: confirmed (binary, runtime dump)

### SaveConfiguration

```lua
System.SaveConfiguration()
```

C++: `int SaveConfiguration (IFunctionHandler * pH )`

Saves the configuration.

docs: y · retail: unconfirmed

### ScanDirectory

```lua
System.ScanDirectory(pszFolderName, nScanMode)
```

Scans a directory.

| Param | Description |
|---|---|
| pszFolderName | Folder name. |
| nScanMode | Scan mode for the folder. Can be: SCANDIR_ALL SCANDIR_FILES SCANDIR_SUBDIRS |

docs: y · retail: confirmed (binary, runtime dump, vanilla×2 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Utils/ScriptLoader.lua`))

### ScreenToTexture

```lua
System.ScreenToTexture()
```

C++: `int ScreenToTexture (IFunctionHandler * pH )`

docs: y · retail: confirmed (binary, runtime dump)

### SetBudget

```lua
System.SetBudget(sysMemLimitInMB, videoMemLimitInMB, frameTimeLimitInMS, soundChannelsPlayingLimit, soundMemLimitInMB, numDrawCallsLimit)
```

Sets system budget.

| Param | Description |
|---|---|
| sysMemLimitInMB | Limit of the system memory in MB. |
| videoMemLimitInMB | Limit of the video memory in MB. |
| frameTimeLimitInMS | Limit in the frame time in MS. |
| soundChannelsPlayingLimit | Limit of the sound channels playing. |
| soundMemLimitInMB | Limit of the sound memory in MB. |
| numDrawCallsLimit | Limit of the draw calls. |

docs: y · retail: confirmed (binary, runtime dump)

### SetConsoleImage

```lua
System.SetConsoleImage(pszName, bRemoveCurrent)
```

Sets the console image.

| Param | Description |
|---|---|
| pszName | Texture image. |
| bRemoveCurrent | True to remove the current image, false otherwise. |

docs: y · retail: confirmed (binary, runtime dump)

### SetCVar

```lua
System.SetCVar(sCVarName, value)
```

Sets the value of a CVariable.

| Param | Description |
|---|---|
| sCVarName | Name of the variable. |
| value | Value of the variable. |

docs: y · retail: confirmed (binary, runtime dump, vanilla×36 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Debug/CombatDebug.lua`), mod×29)

### SetGammaDelta

```lua
System.SetGammaDelta(fDelta)
```

Sets the gamma/delta value.

| Param | Description |
|---|---|
| fDelta | Delta value. |

docs: y · retail: confirmed (binary, runtime dump)

### SetHDRDynamicMultiplier

```lua
System.SetHDRDynamicMultiplier(fMul)
```

Sets the HDR dynamic multiplier.

| Param | Description |
|---|---|
| fMul | Dynamic multiplier value. |

docs: y · retail: unconfirmed

### SetPostProcessFxParam

```lua
System.SetPostProcessFxParam(pszEffectParam, value)
```

Sets a post processing effect parameter value.

| Param | Description |
|---|---|
| pszEffectParam | Parameter for the post processing effect. |
| value | Value for the parameter. |

docs: y · retail: confirmed (binary, runtime dump)

### SetScissor

```lua
System.SetScissor(x, y, w, h)
```

Sets scissor info.

set scissoring screen area

| Param | Description |
|---|---|
| x | X position. |
| y | Y position. |
| w | Width size. |
| h | Height size. |

docs: y · retail: confirmed (binary, runtime dump)

### SetScreenFx

```lua
System.SetScreenFx(pszEffectParam, value)
```

Sets a post processing effect parameter value.

| Param | Description |
|---|---|
| pszEffectParam | Parameter for the post processing effect. |
| value | Value for the parameter. |

docs: y · retail: confirmed (runtime dump, vanilla×18 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/Others/Hazard.lua`))

### SetSkyColor

```lua
System.SetSkyColor(vColor)
```

Set color of the sky (outdoors ambient color).

| Param | Description |
|---|---|
| Vec3 vColor | Sky Color as an {x,y,z} vector (x=r,y=g,z=b). |

docs: y · retail: confirmed (binary, runtime dump, vanilla×2 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/Render/Lightning.lua`))

### SetSkyHighlight

```lua
System.SetSkyHighlight(params)
```

C++: `int GetSkyHighlight (IFunctionHandler* pH , SmartScriptTable params )`

Retrieves Sky highlighing parameters. ! see SetSkyHighlight for parameters description. !

docs: y · retail: confirmed (binary, runtime dump, vanilla×4 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/Render/Flash.lua`))

### SetSunColor

```lua
System.SetSunColor(vColor)
```

Set color of the sun, only relevant outdoors.

| Param | Description |
|---|---|
| Vec3 vColor | Sun Color as an {x,y,z} vector (x=r,y=g,z=b). |

docs: y · retail: confirmed (binary, runtime dump)

### SetSystemShaderRenderFlags

```lua
System.SetSystemShaderRenderFlags(const char *pszShaderName, const char *pszFlagName, bool bEnable)
```

Sets the render flags for the system shader.

| Param | Description |
|---|---|
| pszShaderName | Shader name. |
| pszFlagName | Flag name for the shader. |
| bEnable | True to enable the shader flag, false otherwise. |

docs: y · retail: unconfirmed

### SetViewCameraFov

```lua
System.SetViewCameraFov(fov)
```

C++: `int SetViewCameraFov (IFunctionHandler * pH , float fov )`

Sets the view camera fov.

docs: y · retail: confirmed (runtime dump)

### SetVolumetricFogModifiers

```lua
System.SetVolumetricFogModifiers(gobalDensityModifier, atmosphereHeightModifier)
```

Sets the volumetric fog modifiers.

| Param | Description |
|---|---|
| gobalDensityModifier | Modifier for the global density. |
| atmosphereHeightModifier | Modifier for the atmosphere height. |

docs: y · retail: confirmed (binary, runtime dump, vanilla×1 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/Render/Fog.lua`))

### SetWaterVolumeOffset

```lua
System.SetWaterVolumeOffset()
```

C++: `int SetWaterVolumeOffset (IFunctionHandler * pH )`

SetWaterLevel is not supported by 3dengine for now.

docs: y · retail: confirmed (binary, runtime dump)

### SetWind

```lua
System.SetWind(vWind)
```

Sets the wind direction.

| Param | Description |
|---|---|
| vWind | Wind direction. |

docs: y · retail: confirmed (binary, runtime dump, vanilla×4 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/Others/Wind.lua`))

### ShowConsole

```lua
System.ShowConsole(nParam)
```

Shows/hides the console.

| Param | Description |
|---|---|
| nParam | 1 to show the console, 0 to hide. |

docs: y · retail: confirmed (binary, runtime dump)

### ShowDebugger

```lua
System.ShowDebugger()
```

C++: `int ShowDebugger (IFunctionHandler * pH )`

Shows the debugger.

docs: y · retail: confirmed (binary, runtime dump, vanilla×1 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Utils/Containers.lua`))

### SpawnEntity

```lua
System.SpawnEntity(params)
```

Spawns an entity.

| Param | Description |
|---|---|
| SmartScriptTable params | Entity parameters. |

docs: y · retail: confirmed (binary, runtime dump, vanilla×6 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Debug/CombatDebug.lua`), mod×136)

### ViewDistanceSet

```lua
System.ViewDistanceSet(fViewDist)
```

Sets the view distance.

| Param | Description |
|---|---|
| fViewDist | View distance. |

docs: y · retail: confirmed (binary, runtime dump, vanilla×2 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/Render/ViewDist.lua`))

### Warning

```lua
System.Warning(sText)
```

Shows a message text with the warning severity.

| Param | Description |
|---|---|
| sText | Text to be logged. |

docs: y · retail: confirmed (binary, runtime dump)

## Undocumented (present in retail, not in official docs)

### GetEntityPositionAndDirection

`System.GetEntityPositionAndDirection(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (binary, runtime dump)

### GetSkyHighlight

`System.GetSkyHighlight(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (binary, runtime dump)

### GetWind

`System.GetWind(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (binary, runtime dump, vanilla×2 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/Others/Wind.lua`))

### SetOutdoorAmbientColor

`System.SetOutdoorAmbientColor(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (binary, runtime dump)

### ViewDistanceGet

`System.ViewDistanceGet(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (binary, runtime dump, vanilla×2 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/Render/ViewDist.lua`))

## Verified corrections (not a real function here)

### ExecuteConsoleString

> **Verified note:** `System.ExecuteConsoleString` is not a Lua ScriptBind function -- it is not callable from Lua at all. To run a console line, cvar assignment, or command from Lua use `System.ExecuteCommand(cmd)`. Separately, the Skald node `wh::conceptmodule::ExecuteConsoleString` exists but is marked Style="Debug" and does not work in the retail game (Modding Tools build only). -- kcd2/skald-quests-dialog.md#lua-skald-bridge (verified in game); kcd2/lua-scripting.md#how-mod-lua-gets-loaded (verified in game)
