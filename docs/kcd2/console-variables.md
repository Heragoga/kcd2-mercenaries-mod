---
title: Console variables
summary: How KCD2 cvars work, what the prefix groups are, and which ones this mod or vanilla scripts actually touch.
tags: [engine, tooling, data]
kind: reference
status: current
scope: kcd2
verified: release_1_5_1308617_856
---

# Console variables

## TL;DR

- 5953 names recovered from the binary (632 of those recovered by this generator's own case-insensitive harvest -- the corpus's `cvars` table only captures lowercase-starting names); 3803 classified (kind + call-site evidence), 2150 left `unknown` (no registration call-site could be tied to the name).
- Full machine-readable list: [`data/cvars.tsv`](data/cvars.tsv) (see [`data/README.md`](data/README.md) for columns/confidence).
- Set from Lua with `System.SetCVar(name, value)` / read with `System.GetCVar(name)`; from the console directly by typing `name value`; from a `.cfg` file (e.g. the mod's own `system.cfg`) as `name = value`.
- Commands (as opposed to variables) are invoked the same way from the console, or from Lua via `System.ExecuteCommand`, but take no persisted value -- they run a function.
- `kind: unknown` rows in the tsv are strings that merely look cvar-shaped in the binary (see `data/README.md`'s known gaps); don't assume every row is a real, settable cvar.

## How cvars work in KCD2

- **Setting.** `System.SetCVar("name", value)` from Lua (used throughout `data/` and vanilla `Scripts/`, see [`lua-scripting.md`](lua-scripting.md)); typing `name value` at the console (`~`); or `name = value` in a loaded `.cfg` (the mod ships `system.cfg`, loaded like vanilla's `autoexec.cfg`/`user.cfg`). To run an arbitrary console line, cvar assignment, or command from Lua use [`System.ExecuteCommand(cmd)`](api/System.md#executecommand) -- `System.ExecuteConsoleString` is not a Lua function (see `api/System.md`'s verified note on it).
- **Reading.** `System.GetCVar("name")` from Lua; internally the engine mostly avoids repeated by-name lookups by caching the `ICVar*` returned from registration or the first `GetCVar` call (see `docs/mercenaries/tech/disassembly.md`-style analysis in `data/README.md`'s method section) -- most cvars show exactly one referencing function in the corpus for this reason.
- **Persistence.** Only cvars registered with an archive/save flag persist across sessions; this generator does not currently decode the flags argument (see `data/README.md` gaps), so persistence per-cvar is not listed here -- check in-game with `merc_dev`-style save/reload testing, or read the flags argument by hand with `python tools/disasm_query.py dis <registered_in fn>`.
- **`-devmode` / restrictions.** Gates ~350 authoring console commands and is read back via `System.IsDevModeEnable()`; see [`debugging.md`](debugging.md#console-and-dev-mode) for how to set it and what it does and doesn't gate.
- This mod's own commands (`merc_*`) are a separate, hand-maintained system layered on top -- see `console.md`; they are not in `data/cvars.tsv` at all (that file is the retail-binary corpus only).

## Prefix groups

Counts from `data/cvars.tsv`. `prefix_group` is just "text before the first underscore, lowercased" -- a rough grouping, not an authoritative subsystem map. Subsystem guesses below are from CryEngine/KCD2 naming convention, not verified per-prefix against the binary.

| Prefix | Count | Likely subsystem |
|---|---|---|
| `wh_` | 2783 | Warhorse-specific (this game, not stock CryEngine) -- gameplay, AI tuning, UI, audio, save/load |
| `r_` | 676 | Renderer |
| `e_` | 569 | 3D engine (entities, terrain, vegetation, SVOTI GI, ...) |
| `ai_` | 343 | CryEngine AI system (perception, navigation, behaviour-tree plumbing) |
| `g_` | 272 | Gameplay (CryAction / game logic) |
| `sys_` | 163 | Core system (engine startup, threading, memory, crash handling) |
| `ca_` | 151 | Character (CharEdit / animation asset loading) |
| `cl_` | 135 | Client/network |
| `p_` | 100 | Physics |
| `es_` | 75 | Entity system |
| `i_` | 48 | (unverified) |
| `ui_` | 46 | (unverified) |
| `ac_` | 45 | Character animation (CryAnimation) |
| `pl_` | 40 | Player |
| `sv_` | 32 | (unverified) |
| `v_` | 32 | (unverified) |
| `pad_` | 32 | (unverified) |
| `net_` | 25 | Networking |
| `demo_` | 25 | (unverified) |
| `s_` | 22 | Sound (legacy CrySound path) |
| `mfx_` | 18 | Material effects (impact FX, surface sounds) |
| `log_` | 17 | (unverified) |
| `xi_` | 17 | (unverified) |
| `aim_` | 14 | (unverified) |
| `gfx_` | 14 | (unverified) |
| `q_` | 13 | Quality/graphics presets |
| `dlg_` | 11 | (unverified) |
| `bt_` | 10 | (unverified) |
| `dice_` | 9 | (unverified) |
| `sword_` | 9 | (unverified) |
| `ag_` | 8 | (unverified) |
| `lua_` | 8 | (unverified) |
| `alch_` | 7 | (unverified) |
| `ctrl_` | 7 | (unverified) |
| `t_` | 6 | (unverified) |
| `c_` | 6 | (unverified) |
| `build_` | 6 | (unverified) |
| `read_` | 6 | (unverified) |
| `watch_` | 6 | (unverified) |
| `con_` | 5 | (unverified) |
| ... 68 more prefixes | | see `data/cvars.tsv` |

Kind breakdown: cvar 3569, command 234, unknown 2150 (see confidence notes in `data/README.md` -- `unknown` is mostly recovery failure, not necessarily a non-cvar).

## Cvars modders actually touch

Only cvars that this mod's own Lua, vanilla scripts, or a repo doc actually reference -- i.e. rows from `data/cvars.tsv` with a nonzero `mod_uses`/`vanilla_script_uses` or a `notes_doc` hit. Sorted by how much this mod + vanilla scripts use it. Full list (~5,300 rows) is `data/cvars.tsv`; this is the subset worth reading before touching combat/AI/rendering tuning.

| Cvar | Default | Effect | Doc |
|---|---|---|---|
| `g_gameRules` | (unverified) | (unverified) |  |
| `g_localActor` | (unverified) | (unverified) |  |
| `ac_disableLivingVsRigidCollisions` | (unverified) | Disable collisions between living and rigid entities. Must reload leve... | [gotchas.md](gotchas.md) |
| `wh_ai_ObstaclesAddToCollisionAvoidance` | (unverified) | Add static obstacles to the collision avoidance. 0 - no, 1 - yes, 2 - ... | [world-and-physics.md](world-and-physics.md) |
| `ai_AdjustPathsAroundDynamicObstacles` | (unverified) | (unverified) | [world-and-physics.md](world-and-physics.md) |
| `ai_CollisionAvoidanceRange` | (unverified) | Range for collision avoidance. | [world-and-physics.md](world-and-physics.md) |
| `ai_ExtraAvoidanceRadius` | (unverified) | (unverified) | [world-and-physics.md](world-and-physics.md) |
| `ai_MinActorDynamicObstacleAvoidanceRadius` | (unverified) | (unverified) | walls-and-sieges.md |
| `ai_MovementSystemPathReplanningEnabled` | (unverified) | (unverified) | [world-and-physics.md](world-and-physics.md) |
| `sys_spec` | (unverified) | Tells the system cfg spec. (0=custom, 1=low, 2=med, 3=high, 4=very hig... | [npc-rendering-and-lod.md](npc-rendering-and-lod.md) |
| `wh_gfx_useSWF` | (unverified) | Loads .SWF if .GFX not found | [engine-internals.md](engine-internals.md) |
| `ai_CollisionAvoidanceObstacleTimeHorizon` | (unverified) | Time horizon used to calculate an agent's collision free velocity agai... |  |
| `ai_ExtraActorAvoidanceRadius` | (unverified) | (unverified) |  |
| `ai_ObstacleSizeThreshold` | (unverified) | Obstacle size in meters that differentiates small obstacles from big o... |  |
| `e_ViewDistRatio` | (unverified) | View distance ratio for objects | [glossary.md](glossary.md) |
| `g_PhysicsCollisionClass` | (unverified) | (unverified) | [lua-scripting.md](lua-scripting.md) |
| `g_localActorId` | (unverified) | (unverified) | [lua-scripting.md](lua-scripting.md) |
| `r_DisplayInfo` | (unverified) | (unverified) | [debugging.md](debugging.md) |
| `use_other` | (unverified) | (unverified) | camp.md |
| `wh_ai_AutomaticMNMRebuild` | (unverified) | Enables automatic rebuilding of nav mesh when a change in level is det... | [world-and-physics.md](world-and-physics.md) |
| `wh_ai_FindPathObstaclesMultiplier` | (unverified) | Distance multiplier that is added as extra cost to the part of paths w... | [world-and-physics.md](world-and-physics.md) |
| `wh_ai_FindPathUseObstacles` | (unverified) | Include obstacles when computing costs within the nav mesh search | [world-and-physics.md](world-and-physics.md) |
| `wh_ent_ShowHelperObjects` | (unverified) | (unverified) |  |
| `WH_AI_LOD_MaxCountDetail` | (unverified) | (unverified) | [npc-rendering-and-lod.md](npc-rendering-and-lod.md) |
| `ac_ColliderModeAI` | (unverified) | Force override collider mode for all AI. | [world-and-physics.md](world-and-physics.md) |
| `ai_CollisionAvoidanceEnableRadiusIncrement` | (unverified) | (unverified) | [world-and-physics.md](world-and-physics.md) |
| `ai_CollisionAvoidancePathEndCutoffRange` | (unverified) | Distance from it's current path end for an agent to stop avoiding obst... | [world-and-physics.md](world-and-physics.md) |
| `ai_CollisionAvoidanceTargetCutoffRange` | (unverified) | Distance from it's current target for an agent to stop avoiding obstac... | [world-and-physics.md](world-and-physics.md) |
| `ai_CollisionAvoidanceUpdateVelocities` | (unverified) | (unverified) |  |
| `alch_use` | (unverified) | (unverified) | camp.md |
| `ca_ClothBypassSimulation` | (unverified) | (unverified) | [npc-rendering-and-lod.md](npc-rendering-and-lod.md) |
| `e_LodFaceAreaTargetSizeCharacterWH` | (unverified) | Target radian span for LOD vertices for Characters. | [npc-rendering-and-lod.md](npc-rendering-and-lod.md) |
| `e_ShadowsAutoBias` | (unverified) | (unverified) |  |
| `e_ViewDistRatioVegetation` | (unverified) | View distance ratio for vegetation |  |
| `g_localChannelId` | (unverified) | (unverified) |  |
| `g_varContext` | (unverified) | (unverified) |  |
| `gfx_debugdraw` | (unverified) | (unverified) |  |
| `gfx_draw` | (unverified) | Draw UI Elements |  |
| `lua_dump_state` | (unverified) | Dumps the current state of the lua memory (defined symbols and values)... | [README.md](api/README.md) |
| `r_AuxGeomAutoScaleOver1080pWH` | (unverified) | Enable aux geom text scale for high resolutions. Values in-between 0 a... | [gotchas.md](gotchas.md) |
| `r_GetScreenShot` | (unverified) | (unverified) | camp-inspection.md |
| `r_getscreenshot` | (unverified) | (unverified) | camp-inspection.md |
| `wh_ai_CollisionAvoidanceCircularQueryRadius` | (unverified) | Radius for the circular query used to select potential candidates for ... |  |
| `wh_ai_DisableORCAInBattle` | 1 | Is ORCA disabled during battle game context | [combat-and-perception.md](combat-and-perception.md) |
| `wh_ai_OverrideMNM` | (unverified) | Recast navmesh and detour pathfinding are used in the movement. | walls-and-sieges.md |
| `wh_ca_ClothEnableSimulationSSaxisSizePerc` | (unverified) | (unverified) |  |
| `wh_ca_PendulumMaxLodToSimulate` | (unverified) | (unverified) | [npc-rendering-and-lod.md](npc-rendering-and-lod.md) |
| `WH_AI_CombatDirectionFactor` | (unverified) | (unverified) |  |
| `WH_AI_CombatMove_CheckRadius` | (unverified) | (unverified) |  |
| `WH_AI_CombatMove_ForeignTargetRepulsion` | (unverified) | (unverified) | combat-movement.md |
| `WH_AI_CombatMove_HistoryWeight` | (unverified) | (unverified) |  |
| `WH_AI_CombatMove_M1ObstacleWeight` | (unverified) | (unverified) |  |
| `WH_AI_CombatMove_M2MyWeight` | (unverified) | (unverified) |  |
| `WH_AI_CombatMove_ObstacleWeight` | (unverified) | (unverified) | [world-and-physics.md](world-and-physics.md) |
| `WH_AI_LOD_Areas` | (unverified) | 0 - only distance is used for NPC LOD resolution, 1 - filtered by LOD ... | [npc-rendering-and-lod.md](npc-rendering-and-lod.md) |
| `WH_AI_LOD_HysteresisMultiplierDetail` | (unverified) | (unverified) | npc-lod.md |
| `WH_AI_LOD_MaxCountLOD` | (unverified) | (unverified) | [npc-rendering-and-lod.md](npc-rendering-and-lod.md) |
| `WH_AI_LOD_MaxDetailDistance` | (unverified) | (unverified) | [npc-rendering-and-lod.md](npc-rendering-and-lod.md) |
| `WH_Move_OffMeshStuckDetectionMultiplier` | (unverified) | Multiplier for the predicted threshold for the off mash stuck detectio... | [world-and-physics.md](world-and-physics.md) |
| `ac_ColliderModePlayer` | (unverified) | Force override collider mode for all players. |  |
| `ac_disableLivingVsLivingCollisions` | (unverified) | Disable collisions between living entities. Must reload level (or upda... | [combat-and-perception.md](combat-and-perception.md) |
| `ac_enableExtraSolidCollider` | (unverified) | Enable extra solid collider (for non-pushable characters). | [world-and-physics.md](world-and-physics.md) |
| `ac_movementControlMethodHor` | (unverified) | Overrides the horizontal movement control method specified by AG (over... | [world-and-physics.md](world-and-physics.md) |
| `ai_CollisionAvoidanceAgentExtraFat` | (unverified) | Extra radius to use in Collision Avoidance calculations as a buffer. |  |
| `ai_CollisionAvoidanceAgentTimeHorizon` | (unverified) | Time horizon used to calculate an agent's collision free velocity agai... |  |
| `ai_CollisionAvoidanceClampVelocitiesWithNavigationMesh` | (unverified) | (unverified) | [world-and-physics.md](world-and-physics.md) |
| `ai_CollisionAvoidanceMinSpeed` | (unverified) | Minimum speed allowed to be used by ORCA. |  |
| `ai_CollisionAvoidanceRadiusIncrementDecreaseRate` | (unverified) | Decrease rate of the collision avoidance radius increment. |  |
| `ai_CollisionAvoidanceRadiusIncrementIncreaseRate` | (unverified) | Increase rate of the collision avoidance radius increment. |  |
| `ai_CollisionAvoidanceSmartObjectCutoffRange` | (unverified) | Distance from it's next smart object for an agent to stop avoiding obs... |  |
| `ai_DebugDrawCollisionAvoidanceAgentName` | (unverified) | Name of the agent to draw collision avoidance data for. |  |
| `ai_DebugDrawCollisionAvoidanceObstaclesForAgent` | (unverified) | (unverified) | walls-and-sieges.md |
| `ai_DebugDrawNavigation` | (unverified) | (unverified) |  |
| `ai_DebugDrawNavigationWorldMonitor` | (unverified) | (unverified) | walls-and-sieges.md |
| `ai_EnableORCA` | (unverified) | (unverified) |  |
| `ai_ExtraForbiddenRadiusDuringBeautification` | (unverified) | Extra radius added to agents close to forbidden edges during beautific... |  |
| `ai_MNMAllowDynamicRegenInEditor` | (unverified) | (unverified) |  |
| `ai_NavGenThreadJobs` | (unverified) | (unverified) |  |
| `ai_NavigationSystemMT` | (unverified) | (unverified) |  |
| `ai_PathfinderDangerCostForAttentionTarget` | (unverified) | (unverified) |  |
| `ai_PathfinderDangerCostForExplosives` | (unverified) | (unverified) |  |
| `ai_PathfinderExplosiveDangerMaxThreatDistance` | (unverified) | Range used to decide if evaluate an explosive danger as an actual thre... |  |
| `ai_PathfinderExplosiveDangerRadius` | (unverified) | Range used to evaluate the explosive threats in the path calculation. ... |  |
| `ai_PathfinderGroupMatesAvoidanceRadius` | (unverified) | Range used to evaluate the group mates avoidance in the path calculati... |  |
| `ca_AttachmentCullingRation` | (unverified) | ration between size of attachment and distance to camera | npc-lod.md |
| `ca_DrawAttachmentsMergedForShadows` | (unverified) | (unverified) | performance.md |
| `ca_UseJointMasking` | (unverified) | (unverified) | performance.md |
| `cl_comment` | (unverified) | Hide/Unhide comments in game-mode |  |
| `dlg_horse_cannotMount` | (unverified) | (unverified) |  |
| `e_CharLodMin` | (unverified) | (unverified) | npc-lod.md |
| `e_CharRenderLodMin` | (unverified) | (unverified) | npc-lod.md |
| `e_LodFaceAreaTargetSize` | (unverified) | Target radian span for LOD vertices. |  |
| `e_LodFaceAreaTargetSizeVegetationWH` | (unverified) | Target radian span for LOD vertices for Vegetation. |  |
| `e_MergedMeshes` | (unverified) | (unverified) |  |
| `e_MergedMeshesInstanceDist` | (unverified) | Distance fudge factor at which merged meshes turn off animation | [npc-rendering-and-lod.md](npc-rendering-and-lod.md) |
| `e_MergedMeshesLodRatio` | (unverified) | merged meshes lod ratio | malesov-test.md |
| `e_MergedMeshesViewDistRatio` | (unverified) | merged meshes view dist ratio | [npc-rendering-and-lod.md](npc-rendering-and-lod.md) |
| `e_ShadowsCastViewDistRatioLights` | (unverified) | View dist ratio for shadow maps casting for light sources | malesov-test.md |
| `e_TimeOfDaySpeed` | (unverified) | Time of Day change speed |  |
| `e_Vegetation` | (unverified) | (unverified) |  |
| `e_ViewDistRatioCustom` | (unverified) | View distance ratio for special marked objects (Players,AI,Vehicles) | npc-lod.md |
| `gcc_player_all` | (unverified) | (unverified) | [world-and-physics.md](world-and-physics.md) |
| `gfx_enabled` | (unverified) | Enables the general FlashUI. |  |
| `gfx_uiaction_enable` | (unverified) | Enables UI Actions |  |
| `gfx_uiaction_folder` | (unverified) | Default folder for UIActions | [ui-scaleform.md](ui-scaleform.md) |
| `grab_body` | (unverified) | (unverified) |  |
| `mount_horse` | (unverified) | (unverified) |  |
| `r_AuxGeomFontAutoScaleMultiplierOver1080pWH` | (unverified) | Multiplier for aux geom font auto scaling on high resolutions. Value 0... |  |
| `r_Height` | (unverified) | (unverified) |  |
| `r_ShadowCastingLightsBudgetWH` | (unverified) | (unverified) |  |
| `r_TexturesStreamPoolSize` | (unverified) | (unverified) |  |
| `r_Width` | (unverified) | (unverified) |  |
| `r_auxGeom` | (unverified) | (unverified) | [ui-scaleform.md](ui-scaleform.md) |
| `r_enableAuxGeom` | (unverified) | (unverified) | [ui-scaleform.md](ui-scaleform.md) |
| `r_height` | (unverified) | (unverified) |  |
| `r_width` | (unverified) | (unverified) |  |
| `sound_sound` | (unverified) | (unverified) |  |
| `t_GameScale` | (unverified) | Game time scaled by this - for variable slow motion | [gotchas.md](gotchas.md) |
| `t_Scale` | (unverified) | All times scaled by this - for variable slow motion | [world-and-physics.md](world-and-physics.md) |
| `wh_ai_AdvancedNavMeshSpanMerge` | (unverified) | Use advanced voxel span merge when building navmesh |  |
| `wh_ai_CollisionAvoidanceCandidatesMode` | (unverified) | (unverified) |  |
| `wh_ai_CollisionAvoidanceOutputHalfspace` | (unverified) | (unverified) |  |
| `wh_ai_CryNavigationSystemEnabled` | (unverified) | (unverified) | [world-and-physics.md](world-and-physics.md) |
| `wh_ai_LOD_Hide` | (unverified) | (unverified) | [npc-rendering-and-lod.md](npc-rendering-and-lod.md) |
| `wh_ai_Lod_MoveIntervalLOD` | (unverified) | Time between fake movement jumps in LOD (in seconds). | [npc-rendering-and-lod.md](npc-rendering-and-lod.md) |
| `wh_ai_Lod_MoveIntervalMonsterLOD` | (unverified) | Time between fake movement jumps in MonsterLOD (in seconds). | npc-lod.md |
| `wh_ai_MovementTeleportWhenStuck` | (unverified) | (unverified) | [world-and-physics.md](world-and-physics.md) |
| `wh_ai_NavMeshInUserData` | (unverified) | Saves the tile cache file into the user data |  |
| `wh_ai_NonCircleCollisionAvoidance` | (unverified) | (unverified) |  |
| `wh_ai_StuckDetectionAllowAnyMovement` | (unverified) | (unverified) | [world-and-physics.md](world-and-physics.md) |
| `wh_ai_TileCacheAsBuildBuffer` | 200 | (unverified) |  |
| `wh_ai_TransformManagerForceUpdateCloseObjects` | (unverified) | Enables forced update of close objects in each update |  |
| `wh_ai_TransformManagerUpdateBudget` | 200 | Limit of updates within transform manager. Use negative values to disa... |  |
| `wh_ca_AnimationComputationJobBatchSize` | (unverified) | (unverified) | performance.md |
| `wh_ca_ClothBudgetMaxFramesToSkip` | (unverified) | (unverified) | performance.md |
| `wh_ca_ClothBudgetMaxSSaxisSizePercToSkipFrames` | (unverified) | (unverified) |  |
| `wh_ca_ClothDisableSimulationAtDistanceCollMode1` | (unverified) | (unverified) | malesov-test.md |
| `wh_ca_ClothDisableSimulationAtDistanceCollMode2` | (unverified) | (unverified) |  |
| `wh_ca_SocketsBypassSimulation` | (unverified) | (unverified) |  |
| `wh_cc_LodForUberlod` | (unverified) | (unverified) | [glossary.md](glossary.md) |
| `wh_cc_UberlodLoadDistRatio` | (unverified) | (unverified) | [glossary.md](glossary.md) |
| `wh_cc_UnloadHysteresisDist` | (unverified) | hysteresis distance for unloading uberlod and attachments [m] | npc-lod.md |
| `wh_cs_AutomationAction_ZoneChangeToAttackMinDelay` | (unverified) | Combat automation - min time between zone change and attack (for visua... |  |
| `wh_cs_PlayerHorizontalUnlockDelay` | (unverified) | Delay before player unlocks from opponent when moving in horizontal di... |  |
| `wh_cs_PlayerInputCombatUnlockDelay` | (unverified) | Time in sec to unlock from combat when player changes target with mous... |  |
| `wh_cs_PlayerInputCursorUnlockDistance` | (unverified) | Minimal angle to unlock cursor. |  |
| `wh_cs_PlayerInputLockAreaWidth` | (unverified) | Distance from opponent in metres to start locking (X axis). |  |
| `wh_cs_PlayerInputLockingTolerance` | (unverified) | Player input - Screen distance vertical tolerance from target defining... |  |
| `wh_cs_PlayerInputMouseUnlockMinOppAngle` | (unverified) | Angle to opponent which will reset total distance to unlock. |  |
| `wh_cs_PlayerInputMouseUnlockMinTime` | (unverified) | Minimal time to allow unlocking from selected opponent with mouse. |  |
| `wh_cs_PlayerInputMouseUnlockReturnTime` | (unverified) | Time spent in unlock mode when mouse movement is still before return t... |  |
| `wh_cs_PlayerInputMouseUnlockXThreshold` | (unverified) | Angle X-axis that limits view in camera unlocked mode. |  |
| `wh_cs_PlayerLockOpponentAngleBias` | (unverified) | Bias of FOV angle to lock to opponent. |  |
| `wh_cs_PlayerMaxOpponentAngleToLock` | (unverified) | Maximum possible angle to opponent to lock to combat. |  |
| `wh_cs_PlayerMaxOpponentAngleToUnlock` | (unverified) | Maximum possible angle to opponent before player is unlocked from comb... |  |
| `wh_cs_PlayerMaxOpponentDistanceToLock` | (unverified) | Maximum distance to player lock. |  |
| `wh_cs_PlayerMaxOpponentDistanceToUnlock` | (unverified) | Maximum distance to player unlock. |  |
| `wh_cs_PlayerUnlockTimeout` | (unverified) | Timeout to unlock player from opp when his visibility is lost. |  |
| `wh_cs_PlayerVerticalUnlockDelay` | (unverified) | Delay before player unlocks from opponent when moving in vertical dire... |  |
| `wh_cs_TimeWarpDodgeFadeSpeedForOpp` | (unverified) | (unverified) |  |
| `wh_cs_TimeWarpDodgeFadeSpeedForPlayer` | (unverified) | (unverified) |  |
| `wh_cs_TimeWarpDuration` | (unverified) | (unverified) |  |
| `wh_cs_TimeWarpDurationOpp` | (unverified) | Time of fade out during PB time warp defined relative to hit point. |  |
| `wh_cs_TimeWarpDurationPlayer` | (unverified) | Time of fade out during PB time warp defined relative to hit point. |  |
| `wh_cs_TimeWarpFadeIn` | (unverified) | Time of fade in during PB time warp defined relative to hit point. |  |
| `wh_cs_TimeWarpFadeOut` | (unverified) | Time of fade out during PB time warp defined relative to hit point. |  |
| `wh_cs_TimeWarpPBFadeSpeedForOpp` | (unverified) | (unverified) |  |
| `wh_cs_TimeWarpPBFadeSpeedForPlayer` | (unverified) | (unverified) |  |
| `wh_e_HLodClusterSwitchingDistanceMin` | (unverified) | Minimal switching distance for brush HLods. | [npc-rendering-and-lod.md](npc-rendering-and-lod.md) |
| `wh_e_HLodVegetationSwitchingDistances` | (unverified) | Switching distances for vegetation Lods in meters. |  |
| `wh_e_ReflexLightDiffuseMultiplier` | (unverified) | Multiplies RL color during deserialization from lua. Should be 1, use ... |  |
| `wh_e_ReflexLightSpecularMultiplier` | (unverified) | Multiplies RL specular during deserialization from lua. Should be 1, u... |  |
| `wh_env_RainDebug` | (unverified) | Shows debug info about rain |  |
| `wh_env_RainThreshold` | (unverified) | It starts raining when rainThreshold < localCloud * rainProbability |  |
| `wh_item_ViewDistRatio` | (unverified) | (unverified) | [npc-rendering-and-lod.md](npc-rendering-and-lod.md) |
| `wh_rpg_LockOnAllTargets` | (unverified) | (unverified) |  |
| `wh_rpg_LogInterval` | (unverified) | Interval between saving logs to file (seconds) |  |
| `wh_rpg_LogLevel` | (unverified) | (unverified) |  |
| `wh_rpg_LogReasons` | (unverified) | (unverified) |  |
| `wh_rpg_LogSize` | (unverified) | (unverified) |  |
| `wh_rpg_LogTarget` | (unverified) | (unverified) |  |
| `wh_rpg_LogType` | (unverified) | (unverified) |  |
| `wh_rpg_ResetLogging` | (unverified) | Resets event logging. You have to Reset after changing logging setting... |  |
| `wh_rpg_TelemetryLimitedToPlayline` | (unverified) | (unverified) |  |
| `wh_rpg_UnlockAll` | (unverified) | (unverified) |  |
| `wh_sys_specVersion` | (unverified) | Script can read this to modify its behavior for E3, Gamescom etc. |  |
| `wh_ui_BubbleDebug` | (unverified) | (unverified) |  |
| `wh_ui_BubblesEnabled` | (unverified) | (unverified) |  |
| `wh_ui_ShowHud` | (unverified) | (unverified) |  |
| `C_XGenAIModule` | (unverified) | (unverified) | [SmartObject.md](api/SmartObject.md) |
| `WH_AI_CombatMove_AccelerationLimit` | (unverified) | (unverified) | combat-movement.md |
| `WH_AI_CombatMove_ApproachOffset` | (unverified) | (unverified) | [combat-and-perception.md](combat-and-perception.md) |
| `WH_AI_CombatMove_CirclingChooseMoveMaxProb` | (unverified) | (unverified) | combat-movement.md |
| `WH_AI_CombatMove_CirclingDirectionDurationMin` | (unverified) | (unverified) | combat-movement.md |
| `WH_AI_CombatMove_CirclingLowestMovementActivity` | (unverified) | (unverified) | [unresolved-binds.md](api/unresolved-binds.md) |
| `WH_AI_CombatMove_CirclingWaitingDurationMax` | (unverified) | (unverified) | combat-movement.md |
| `WH_AI_CombatMove_CirclingWaitingDurationMin` | (unverified) | (unverified) | [combat-and-perception.md](combat-and-perception.md) |
| `WH_AI_CombatMove_DestinationRepulsionAlliesOnly` | (unverified) | (unverified) | combat-movement.md |
| `WH_AI_CombatMove_DestinationRepulsionThreshold` | (unverified) | (unverified) | combat-movement.md |
| `WH_AI_CombatMove_ForceKeepDistance` | (unverified) | (unverified) | combat-movement.md |
| `WH_AI_CombatMove_GuardDisableTimeout` | (unverified) | (unverified) | combat-movement.md |
| `WH_AI_CombatMove_GuardEnableTimeout` | (unverified) | (unverified) | combat-movement.md |
| `WH_AI_CombatMove_InfrontCut` | (unverified) | (unverified) | combat-movement.md |
| `WH_AI_CombatMove_MinArcRange` | (unverified) | (unverified) | combat-movement.md |
| `WH_AI_CombatMove_ReactionMinTime` | (unverified) | (unverified) | combat-movement.md |
| `WH_AI_CombatMove_SprintFactorMax` | (unverified) | (unverified) | combat-movement.md |
| `WH_AI_CombatMove_TacticalFollowersUpdate` | (unverified) | (unverified) | combat-movement.md |
| `WH_AI_CombatMove_TacticalRangeGain` | (unverified) | (unverified) | combat-movement.md |
| `WH_AI_CombatMove_TacticalSurround` | (unverified) | (unverified) | [combat-and-perception.md](combat-and-perception.md) |
| `WH_AI_CombatMove_ToGuardFactor` | (unverified) | (unverified) | combat-movement.md |
| `WH_AI_CombatMove_TurnAngleRotationMax` | (unverified) | (unverified) | combat-movement.md |
| `WH_AI_LOD_MLUseFakeMovementMinimalDistance` | (unverified) | (unverified) | npc-lod.md |
| `WH_AI_LOD_MaxCountLODUnstealableByMLWakeUp` | (unverified) | (unverified) | [npc-rendering-and-lod.md](npc-rendering-and-lod.md) |
| `WH_AI_LOD_MaxNonMLDistance` | (unverified) | (unverified) | [npc-rendering-and-lod.md](npc-rendering-and-lod.md) |
| `ai_TargetTracking` | (unverified) | (unverified) | [AI.md](api/AI.md) |
| `ai_body` | (unverified) | (unverified) | [Actor.md](api/Actor.md) |
| `ai_body_id` | (unverified) | (unverified) | npc-lod.md |
| `ai_enums` | (unverified) | (unverified) | [audio-voice-lipsync.md](audio-voice-lipsync.md) |
| `ai_types` | (unverified) | (unverified) | [behavior-trees.md](behavior-trees.md) |
| `ai_variable_form_id` | (unverified) | (unverified) | [make-npc-brain.md](../xml/make-npc-brain.md) |
| `ai_variable_sync_id` | (unverified) | (unverified) | [make-npc-brain.md](../xml/make-npc-brain.md) |
| `alt_f11` | (unverified) | (unverified) | [unresolved-binds.md](api/unresolved-binds.md) |
| `brain_variable` | (unverified) | (unverified) | [ai-brains-and-npcs.md](ai-brains-and-npcs.md) |
| `ca_CharEditModel` | (unverified) | objects/characters/human/sdk_player/sdk_player.cdf | npc-lod.md |
| `ca_DebugFacial` | (unverified) | (unverified) | [audio-voice-lipsync.md](audio-voice-lipsync.md) |
| `ca_ForceUpdateSkeletons` | (unverified) | (unverified) | [npc-rendering-and-lod.md](npc-rendering-and-lod.md) |
| `ca_lipsync_debug` | (unverified) | (unverified) | [audio-voice-lipsync.md](audio-voice-lipsync.md) |
| `ca_lipsync_phoneme_crossfade` | (unverified) | (unverified) | [audio-voice-lipsync.md](audio-voice-lipsync.md) |
| `dice_badge_use` | (unverified) | (unverified) | [unresolved-binds.md](api/unresolved-binds.md) |
| `dice_hold` | (unverified) | (unverified) | [unresolved-binds.md](api/unresolved-binds.md) |
| `dice_pass` | (unverified) | (unverified) | [unresolved-binds.md](api/unresolved-binds.md) |
| `dice_score` | (unverified) | (unverified) | [unresolved-binds.md](api/unresolved-binds.md) |
| `e_ObjectLayersActivation` | (unverified) | (unverified) | [EntityModule.md](api/EntityModule.md) |
| `es_DebugEvents` | (unverified) | (unverified) | [npc-rendering-and-lod.md](npc-rendering-and-lod.md) |
| `g_debugCollisionDamage` | (unverified) | (unverified) | [world-and-physics.md](world-and-physics.md) |
| `g_language` | (unverified) | Defines which language pak is loaded | [Sound.md](api/Sound.md) |
| `g_languageAudio` | (unverified) | Will automatically match g_language setting unless specified otherwise | [audio-voice-lipsync.md](audio-voice-lipsync.md) |
| `gcc_all_engine` | (unverified) | (unverified) | [world-and-physics.md](world-and-physics.md) |
| `gcc_all_game` | (unverified) | (unverified) | [world-and-physics.md](world-and-physics.md) |
| `gcc_npc_avoiding_types` | (unverified) | (unverified) | [world-and-physics.md](world-and-physics.md) |
| `horse_inspect_close` | (unverified) | (unverified) | [unresolved-binds.md](api/unresolved-binds.md) |
| `log_Verbosity` | (unverified) | (unverified) | [debugging.md](debugging.md) |
| `mn_tags` | (unverified) | (unverified) | loot-sweep.md |
| `p_draw_helpers` | (unverified) | (unverified) | [assets-pipeline.md](assets-pipeline.md) |
| `r_D3D12HardwareComputeQueue` | (unverified) | (unverified) | [unresolved-binds.md](api/unresolved-binds.md) |
| `r_D3D12HardwareCopyQueue` | (unverified) | (unverified) | [unresolved-binds.md](api/unresolved-binds.md) |
| `r_Stats` | (unverified) | (unverified) | [debugging.md](debugging.md) |
| `r_TexelsPerMeter` | (unverified) | (unverified) | [assets-pipeline.md](assets-pipeline.md) |
| `s_AudioSystemImplementationName` | (unverified) | CryAudioImplWwise | [audio-voice-lipsync.md](audio-voice-lipsync.md) |
| `shop_trader` | (unverified) | (unverified) | camp-trader.md |

... 98 more touched cvars omitted here; see `data/cvars.tsv` filtered on `mod_uses`/`vanilla_script_uses`/`notes_doc`.

## Gotchas

- A cvar with `default` blank in `data/cvars.tsv` is not necessarily undocumented -- many real defaults are computed at runtime and are not recoverable as a literal from the registration call-site (see `data/README.md`).
- `registered_in` function names (`sub_XXXXXXX`) are RVAs for build `release_1_5_1308617_856` only -- they will not match after a game patch. Re-run `tools/gen_cvar_reference.py` after any corpus rebuild rather than hardcoding one elsewhere.
- The disasm corpus's own `cvars` table includes some strings that merely look cvar-shaped (log tags, format strings) -- see `E:\kcd2_disasm\AGENTS.md`. A `kind` of `unknown` with zero `registered_in` hits is likely one of these.
- `docs/mercenaries/ai/combat-movement.md` documents roughly forty combat-movement cvars with verified stock values from in-game testing -- prefer those over this generator's `default` column when they overlap; this generator does not currently merge that table in (see `data/README.md`).
- **632 cvars with an upper-case-starting name** (e.g. `WH_AI_CombatMove_TacticalSurround`) are registered in `WHGame.dll` but invisible to the disasm corpus's own `cvars` table, which only ever captures lowercase-starting names -- this generator recovers them separately (`source` = `harvested (...)` in `data/cvars.tsv`). Prefixes seen: `WH_` (240), `ui_` (46), `pad_` (32), `demo_` (25), `xi_` (17), `r_` (16), `aim_` (14), `gfx_` (14).

See also: [`data/cvars.tsv`](data/cvars.tsv), [`data/README.md`](data/README.md), [`lua-scripting.md`](lua-scripting.md) (calling `SetCVar`/`GetCVar`/`ExecuteCommand` from Lua), [`debugging.md`](debugging.md#console-and-dev-mode) (`-devmode` and reading console output), `console.md` (this mod's own `merc_*` commands), `disassembly.md` (how to query the corpus directly).
