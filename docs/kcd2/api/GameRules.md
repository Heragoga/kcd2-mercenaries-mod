# GameRules

C++ class(es): `C_ScriptBindGameRules`, `C_ScriptBind_GameRules`
Reached from Lua as `GameRules.FunctionName(...)`.
135 documented function(s); 0 additional undocumented function(s) found in retail/runtime.

## Functions

### AbortEntityRemoval

```lua
GameRules.AbortEntityRemoval(ScriptHandle entityId)
```

Aborts the entity removal.

| Param | Description |
|---|---|
| ScriptHandle entityId | Entity identifier. |

docs: y · retail: confirmed (binary)

### AbortEntityRespawn

```lua
GameRules.AbortEntityRespawn(ScriptHandle entityId, bool destroyData)
```

Aborts a respawning for the specified entity.

| Param | Description |
|---|---|
| ScriptHandle entityId | Entity identifier. |
| bool destroyData | True to destroy the data, false otherwise. |

docs: y · retail: confirmed (binary)

### AddMinimapEntity

```lua
GameRules.AddMinimapEntity(ScriptHandle entityId, int type, float lifetime)
```

Adds a mipmap entity.

| Param | Description |
|---|---|
| ScriptHandle entityId | Entity identifier. |
| int type | . |
| float lifetime | . |

docs: y · retail: unconfirmed

### AddObjective

```lua
GameRules.AddObjective(int teamId, const char *objective, int status, ScriptHandle entityId)
```

Adds an objective for the specified team with the specified status.

| Param | Description |
|---|---|
| int teamId | Team identifier. |
| const char * objective | Objective name. |
| int status | Status. |
| ScriptHandle entityId | Entity identifier. |

docs: y · retail: unconfirmed

### AddSpawnGroup

```lua
GameRules.AddSpawnGroup(groupId)
```

Adds a spawn group.

| Param | Description |
|---|---|
| ScriptHandle groupId | Group identifier. |

docs: y · retail: confirmed (binary, vanilla×1)

### AddSpawnLocation

```lua
GameRules.AddSpawnLocation(entityId)
```

Adds the spawn location for the specified entity.

| Param | Description |
|---|---|
| ScriptHandle entityId | Entity identifier. |

docs: y · retail: confirmed (binary, vanilla×3)

### AddSpawnLocationToSpawnGroup

```lua
GameRules.AddSpawnLocationToSpawnGroup(groupId,location)
```

Add a spawn location to spawn a group.

| Param | Description |
|---|---|
| ScriptHandle groupId | Group identifier. |
| ScriptHandle location | Location. |

docs: y · retail: confirmed (binary, vanilla×1)

### AddSpectatorLocation

```lua
GameRules.AddSpectatorLocation(ScriptHandle location)
```

Adds a spectator location.

| Param | Description |
|---|---|
| ScriptHandle location | Location. |

docs: y · retail: unconfirmed

### AttachTo

```lua
GameRules.AttachTo()
```

C++: `virtual void AttachTo (CGameRules * pGameRules )`

docs: y · retail: unconfirmed

### CanChangeSpectatorMode

```lua
GameRules.CanChangeSpectatorMode(ScriptHandle playerId)
```

Check if it's possible to change the spectator mode.

| Param | Description |
|---|---|
| ScriptHandle playerId | Player identifier. |

docs: y · retail: unconfirmed

### CanCheat

```lua
GameRules.CanCheat()
```

C++: `int CanCheat (IFunctionHandler * pH )`

Checks if in this game entity is possible to cheat.

docs: y · retail: confirmed (binary)

### ChangePlayerClass

```lua
GameRules.ChangePlayerClass(int channelId, const char *className)
```

Changes the player class.

| Param | Description |
|---|---|
| int channelId | Channel identifier. |
| const char * className | Name of the new class for the player. |

docs: y · retail: confirmed (binary)

### ChangeSpectatorMode

```lua
GameRules.ChangeSpectatorMode(ScriptHandle playerId, int mode, ScriptHandle targetId)
```

Changes the spectator mode.

| Param | Description |
|---|---|
| ScriptHandle playerId | Player identifier. |
| int mode | New spectator mode. |
| ScriptHandle targetId | Target identifier. |

docs: y · retail: unconfirmed

### CreateTeam

```lua
GameRules.CreateTeam(const char *name)
```

Creates a team.

| Param | Description |
|---|---|
| const char * name | Team name. |

docs: y · retail: confirmed (binary)

### DebugCollisionDamage

```lua
GameRules.DebugCollisionDamage()
```

C++: `int DebugCollisionDamage (IFunctionHandler * pH )`

Debugs collision damage.

docs: y · retail: confirmed (binary)

### DebugHits

```lua
GameRules.DebugHits()
```

C++: `int DebugHits (IFunctionHandler * pH )`

Debugs hits.

docs: y · retail: confirmed (binary)

### EndGame

```lua
GameRules.EndGame()
```

C++: `int EndGame (IFunctionHandler * pH )`

Ends the game.

docs: y · retail: confirmed (binary)

### EndGameNear

```lua
GameRules.EndGameNear(ScriptHandle entityId)
```

| Param | Description |
|---|---|
| ScriptHandle entityId | Entity identifier. |

docs: y · retail: confirmed (binary)

### EnteredGame

```lua
GameRules.EnteredGame()
```

C++: `int EnteredGame (IFunctionHandler* pH )`

Get the game rules and enter the game.

docs: y · retail: confirmed (binary)

### ForbiddenAreaWarning

```lua
GameRules.ForbiddenAreaWarning(bool active, int timer, ScriptHandle targetId)
```

Warnings for a forbidden area.

| Param | Description |
|---|---|
| bool active | . |
| int timer | . |
| ScriptHandle targetId | . |

docs: y · retail: unconfirmed

### ForceScoreboard

```lua
GameRules.ForceScoreboard(bool force)
```

Forces the display of the scoreboard on the HUD.

| Param | Description |
|---|---|
| bool force | True to force scoreboard, false otherwise. |

docs: y · retail: confirmed (binary)

### ForceSynchedStorageSynch

```lua
GameRules.ForceSynchedStorageSynch(int channelId)
```

Forces sync storage syncing.

| Param | Description |
|---|---|
| int channelId | Channel identifier. |

docs: y · retail: unconfirmed

### FreezeEntity

```lua
GameRules.FreezeEntity(ScriptHandle entityId, bool freeze, bool vapor, bool force)
```

| Param | Description |
|---|---|
| ScriptHandle entityId | Entity identifier. |
| bool freeze | True if the entity is froozen, false otherwise. |
| bool vapor | True to spawn vapor after freezing, false otherwise. |
| force | True to force freezing even for the entity that implements "GetFrozen Amount", false otherwise. The default value is false. |

docs: y · retail: unconfirmed

### FreezeInput

```lua
GameRules.FreezeInput(bool freeze)
```

Freezes the input.

| Param | Description |
|---|---|
| bool freeze | True to freeze input, false otherwise. |

docs: y · retail: confirmed (binary)

### GameOver

```lua
GameRules.GameOver(int localWinner)
```

For the power struggle tutorial. Syntax: GameRules.GameOver( int localWinner )

Ends the game with a local winner.

| Param | Description |
|---|---|
| int localWinner | Local winner ID. |

docs: y · retail: confirmed (binary)

### GetChannelId

```lua
GameRules.GetChannelId(playerId)
```

Gets the channel id where the specified player is.

| Param | Description |
|---|---|
| ScriptHandle playerId | Player identifier. |

docs: y · retail: confirmed (binary)

### GetChannelTeam

```lua
GameRules.GetChannelTeam(int channelId)
```

Gets the team in the specified channel.

| Param | Description |
|---|---|
| int channelId | Channel identifier. |

docs: y · retail: confirmed (binary)

### GetFirstSpawnLocation

```lua
GameRules.GetFirstSpawnLocation(int teamId)
```

Gets the first spawn location for the team.

| Param | Description |
|---|---|
| int teamId | Team identifier. |

docs: y · retail: confirmed (binary, vanilla×1)

### GetFragLead

```lua
GameRules.GetFragLead()
```

C++: `int GetFragLead (IFunctionHandler * pH )`

Gets the frag lead.

docs: y · retail: confirmed (binary)

### GetFragLimit

```lua
GameRules.GetFragLimit()
```

C++: `int GetFragLimit (IFunctionHandler * pH )`

Gets the frag limit.

docs: y · retail: confirmed (binary)

### GetFriendlyFireRatio

```lua
GameRules.GetFriendlyFireRatio()
```

C++: `int GetFriendlyFireRatio (IFunctionHandler * pH )`

Gets the friendly fire ratio.

docs: y · retail: confirmed (binary)

### GetHitMaterialId

```lua
GameRules.GetHitMaterialId(const char *materialName)
```

Gets the hit material identifier from its name.

| Param | Description |
|---|---|
| const char * materialName | Name of the material. |

docs: y · retail: confirmed (binary, vanilla×1)

### GetHitMaterialName

```lua
GameRules.GetHitMaterialName(int materialId)
```

Gets the hit material name from its identifier.

| Param | Description |
|---|---|
| int materialId | Material identifier. |

docs: y · retail: confirmed (binary)

### GetHitType

```lua
GameRules.GetHitType()
```

C++: `int GetHitType (IFunctionHandler * pH , int id )`

docs: y · retail: confirmed (binary)

### GetHitTypeId

```lua
GameRules.GetHitTypeId(const char *type)
```

Gets a hit type identifier from the name.

| Param | Description |
|---|---|
| const char * type | Hit type name. |

docs: y · retail: confirmed (binary, vanilla×3)

### GetInterestingSpectatorLocation

```lua
GameRules.GetInterestingSpectatorLocation()
```

C++: `int GetInterestingSpectatorLocation (IFunctionHandler * pH )`

Gets an interesting spectator location.

docs: y · retail: unconfirmed

### GetMinPlayerLimit

```lua
GameRules.GetMinPlayerLimit()
```

C++: `int GetMinPlayerLimit (IFunctionHandler * pH )`

Gets the minimum player limit.

docs: y · retail: confirmed (binary)

### GetMinTeamLimit

```lua
GameRules.GetMinTeamLimit()
```

C++: `int GetMinTeamLimit (IFunctionHandler * pH )`

Gets the minimum team limit.

docs: y · retail: confirmed (binary)

### GetNextSpectatorTarget

```lua
GameRules.GetNextSpectatorTarget(ScriptHandle playerId, int change)
```

C++: `int GetNextSpectatorTarget (IFunctionHandler * pH , ScriptHandle playerId , int change )`

For 3rd person follow-cam mode. Gets the next spectator target.

docs: y · retail: unconfirmed

### GetPing

```lua
GameRules.GetPing(int channelId)
```

Gets the ping to a channel.

| Param | Description |
|---|---|
| int channelId | Channel identifier. |

docs: y · retail: confirmed (binary)

### GetPlayerByChannelId

```lua
GameRules.GetPlayerByChannelId(int channelId)
```

Gets the player from the channel id.

| Param | Description |
|---|---|
| int channelId | Channel identifier. |

docs: y · retail: confirmed (binary)

### GetPlayerCount

```lua
GameRules.GetPlayerCount()
```

C++: `int GetPlayerCount (IFunctionHandler * pH )`

Gets the number of the players.

docs: y · retail: confirmed (binary)

### GetPlayers

```lua
GameRules.GetPlayers()
```

C++: `int GetPlayers (IFunctionHandler * pH )`

Gets the player.

docs: y · retail: confirmed (binary)

### GetPreRoundTime

```lua
GameRules.GetPreRoundTime()
```

C++: `int GetPreRoundTime (IFunctionHandler * pH )`

Gets the pre-round time.

docs: y · retail: confirmed (binary)

### GetRandomSpectatorLocation

```lua
GameRules.GetRandomSpectatorLocation()
```

C++: `int GetRandomSpectatorLocation (IFunctionHandler * pH )`

Gets a random spectator location.

docs: y · retail: unconfirmed

### GetRemainingGameTime

```lua
GameRules.GetRemainingGameTime()
```

C++: `int GetRemainingGameTime (IFunctionHandler * pH )`

Gets the remaining game time.

docs: y · retail: confirmed (binary)

### GetRemainingPreRoundTime

```lua
GameRules.GetRemainingPreRoundTime()
```

C++: `int GetRemainingPreRoundTime (IFunctionHandler * pH )`

Gets the remaining pre-round time.

docs: y · retail: confirmed (binary)

### GetRemainingReviveCycleTime

```lua
GameRules.GetRemainingReviveCycleTime()
```

C++: `int GetRemainingReviveCycleTime (IFunctionHandler * pH )`

Gets the remaining cycle time.

docs: y · retail: confirmed (binary)

### GetRemainingRoundTime

```lua
GameRules.GetRemainingRoundTime()
```

C++: `int GetRemainingRoundTime (IFunctionHandler * pH )`

Gets the remaining round time.

docs: y · retail: confirmed (binary)

### GetRemainingStartTimer

```lua
GameRules.GetRemainingStartTimer()
```

C++: `int GetRemainingStartTimer (IFunctionHandler * pH )`

Gets the remaining start timer.

docs: y · retail: confirmed (binary)

### GetReviveTime

```lua
GameRules.GetReviveTime()
```

C++: `int GetReviveTime (IFunctionHandler * pH )`

Gets the revive time.

docs: y · retail: confirmed (binary)

### GetRoundLimit

```lua
GameRules.GetRoundLimit()
```

C++: `int GetRoundLimit (IFunctionHandler * pH )`

Gets the round time limit.

docs: y · retail: confirmed (binary)

### GetRoundTime

```lua
GameRules.GetRoundTime()
```

C++: `int GetRoundTime (IFunctionHandler * pH )`

Gets the round time.

docs: y · retail: confirmed (binary)

### GetSpawnGroups

```lua
GameRules.GetSpawnGroups()
```

C++: `int GetSpawnGroups (IFunctionHandler * pH )`

Gets spawn groups.

docs: y · retail: confirmed (binary)

### GetSpawnLocation

```lua
GameRules.GetSpawnLocation(playerId, bool ignoreTeam, bool includeNeutral)
```

| Param | Description |
|---|---|
| ScriptHandle playerId | Player identifier. |
| bool ignoreTeam | True to ignore team, false otherwise. |
| bool includeNeutral | True to include neutral entity, false otherwise. |

docs: y · retail: unconfirmed

### GetSpawnLocationByIdx

```lua
GameRules.GetSpawnLocationByIdx(int idx)
```

Gets the spawn location from its identifier.

| Param | Description |
|---|---|
| int idx | Spawn location identifier. |

docs: y · retail: confirmed (binary)

### GetSpawnLocationCount

```lua
GameRules.GetSpawnLocationCount()
```

C++: `int GetSpawnLocationCount (IFunctionHandler * pH )`

Gets the number of the spawn location.

docs: y · retail: confirmed (binary)

### GetSpawnLocationGroup

```lua
GameRules.GetSpawnLocationGroup(spawnId)
```

Gets spawn location group.

| Param | Description |
|---|---|
| ScriptHandle spawnId | Spawn identifier. |

docs: y · retail: confirmed (binary)

### GetSpawnLocations

```lua
GameRules.GetSpawnLocations()
```

C++: `int GetSpawnLocations (IFunctionHandler * pH )`

Gets the spawn locations.

docs: y · retail: confirmed (binary)

### GetSpectatorCount

```lua
GameRules.GetSpectatorCount()
```

C++: `int GetSpectatorCount (IFunctionHandler * pH )`

Gets the number of the spectators.

docs: y · retail: unconfirmed

### GetSpectatorLocation

```lua
GameRules.GetSpectatorLocation(int idx)
```

Gets the spectator location from its identifier.

| Param | Description |
|---|---|
| int idx | Spectator location identifier. |

docs: y · retail: unconfirmed

### GetSpectatorLocationCount

```lua
GameRules.GetSpectatorLocationCount()
```

C++: `int GetSpectatorLocationCount (IFunctionHandler * pH )`

Gets the number of the spectator locations.

docs: y · retail: unconfirmed

### GetSpectatorLocations

```lua
GameRules.GetSpectatorLocations()
```

C++: `int GetSpectatorLocations (IFunctionHandler * pH )`

Gets the spectator locations.

docs: y · retail: unconfirmed

### GetSynchedEntityValue

```lua
GameRules.GetSynchedEntityValue(ScriptHandle entityId, int key)
```

Gets the specified sync entity value.

| Param | Description |
|---|---|
| ScriptHandle entityId | Entity identifier. |
| int key | Key for the sync entity value. |

docs: y · retail: unconfirmed

### GetSynchedGlobalValue

```lua
GameRules.GetSynchedGlobalValue(int key)
```

Gets the sync global value from its key.

| Param | Description |
|---|---|
| int key | Key for the sync global value. |

docs: y · retail: unconfirmed

### GetTeam

```lua
GameRules.GetTeam(ScriptHandle playerId)
```

Gets the team of the specified player.

| Param | Description |
|---|---|
| ScriptHandle playerId | Player identifier. |

docs: y · retail: confirmed (binary, vanilla×5)

### GetTeamChannelCount

```lua
GameRules.GetTeamChannelCount(int teamId)
```

Gets the team channel count.

| Param | Description |
|---|---|
| int teamId | Team identifier. |

docs: y · retail: confirmed (binary)

### GetTeamCount

```lua
GameRules.GetTeamCount()
```

C++: `int GetTeamCount (IFunctionHandler * pH )`

Gets the team number.

docs: y · retail: confirmed (binary)

### GetTeamDefaultSpawnGroup

```lua
GameRules.GetTeamDefaultSpawnGroup(int teamId)
```

Gets team default spawn group.

| Param | Description |
|---|---|
| int teamId | Team identifier. |

docs: y · retail: confirmed (binary)

### GetTeamId

```lua
GameRules.GetTeamId(const char *teamName)
```

Gets the team identifier from the team name.

| Param | Description |
|---|---|
| const char * teamName | Team name. |

docs: y · retail: confirmed (binary, vanilla×4)

### GetTeamLock

```lua
GameRules.GetTeamLock()
```

C++: `int GetTeamLock (IFunctionHandler * pH )`

Gets the team lock.

docs: y · retail: confirmed (binary)

### GetTeamName

```lua
GameRules.GetTeamName(int teamId)
```

Gets the name of the specified team.

| Param | Description |
|---|---|
| int teamId | Team identifier. |

docs: y · retail: confirmed (binary)

### GetTeamPlayerCount

```lua
GameRules.GetTeamPlayerCount(int teamId)
```

Gets the number of players in the specified team.

| Param | Description |
|---|---|
| int teamId | Team identifier. |

docs: y · retail: confirmed (binary)

### GetTeamPlayers

```lua
GameRules.GetTeamPlayers(int teamId)
```

Gets the players in the specified team.

| Param | Description |
|---|---|
| int teamId | Team identifier. |

docs: y · retail: confirmed (binary)

### GetTimeLimit

```lua
GameRules.GetTimeLimit()
```

C++: `int GetTimeLimit (IFunctionHandler * pH )`

Gets the time limit.

docs: y · retail: confirmed (binary)

### IsClient

```lua
GameRules.IsClient()
```

C++: `int IsClient (IFunctionHandler * pH )`

Checks if this entity is a client.

docs: y · retail: confirmed (binary)

### IsDemoMode

```lua
GameRules.IsDemoMode()
```

C++: `int IsDemoMode (IFunctionHandler * pH )`

Checks if the game is running in demo mode.

docs: y · retail: confirmed (binary)

### IsFrozen

```lua
GameRules.IsFrozen(ScriptHandle entityId)
```

Checks if the entity is frozen.

| Param | Description |
|---|---|
| ScriptHandle entityId | Entity identifier. |

docs: y · retail: unconfirmed

### IsInvulnerable

```lua
GameRules.IsInvulnerable(ScriptHandle playerId)
```

Checks if the player is invulnerable.

| Param | Description |
|---|---|
| ScriptHandle playerId | Player identifier. |

docs: y · retail: confirmed (binary, vanilla×3)

### IsNeutral

```lua
GameRules.IsNeutral(entityId)
```

Checks if the entity is neutral.

| Param | Description |
|---|---|
| ScriptHandle entityId | Entity identifier. |

docs: y · retail: confirmed (binary)

### IsPlayerInGame

```lua
GameRules.IsPlayerInGame(playerId)
```

Checks if the specified player is in game.

| Param | Description |
|---|---|
| ScriptHandle playerId | Player identifier. |

docs: y · retail: confirmed (binary)

### IsProjectile

```lua
GameRules.IsProjectile(entityId)
```

Checks if the specified entity is a projectile.

| Param | Description |
|---|---|
| ScriptHandle entityId | Entity identifier. |

docs: y · retail: confirmed (binary)

### IsRoundTimeLimited

```lua
GameRules.IsRoundTimeLimited()
```

C++: `int IsRoundTimeLimited (IFunctionHandler * pH )`

Checks if the round time is limited.

docs: y · retail: confirmed (binary)

### IsSameTeam

```lua
GameRules.IsSameTeam(entityId0,entityId1)
```

Checks if the two entity are in the same team.

| Param | Description |
|---|---|
| ScriptHandle entityId0 | First entity identifier. |
| ScriptHandle entityId1 | Second entity identifier. |

docs: y · retail: confirmed (binary)

### IsServer

```lua
GameRules.IsServer()
```

C++: `int IsServer (IFunctionHandler * pH )`

Checks if this entity is a server.

docs: y · retail: confirmed (binary)

### IsSpawnGroup

```lua
GameRules.IsSpawnGroup(entityId)
```

Checks if the entity is a spawn group.

| Param | Description |
|---|---|
| ScriptHandle entityId | Entity identifier. |

docs: y · retail: confirmed (binary)

### IsTimeLimited

```lua
GameRules.IsTimeLimited()
```

C++: `int IsTimeLimited (IFunctionHandler * pH )`

Checks if the game time is limited.

docs: y · retail: confirmed (binary)

### KillPlayer

```lua
GameRules.KillPlayer(ScriptHandle playerId, bool dropItem, bool ragdoll, ScriptHandle shooterId, ScriptHandle weaponId, float damage, int material, int hit_type, Vec3 impulse)
```

Kills the player.

| Param | Description |
|---|---|
| ScriptHandle playerId | Player identifier. |
| bool dropItem | True to drop the item, false otherwise. |
| bool ragdoll | True to ragdollize, false otherwise. |
| ScriptHandle shooterId | Shooter identifier. |
| ScriptHandle weaponId | Weapon identifier. |
| float damage | Damage amount. |
| int material | Material identifier. |
| int hit_type | Type of the hit. |
| Vec3 impulse | Impulse vector due to the hit. |

docs: y · retail: unconfirmed

### MovePlayer

```lua
GameRules.MovePlayer(ScriptHandle playerId, Vec3 pos, Vec3 angles)
```

Moves the player.

| Param | Description |
|---|---|
| ScriptHandle playerId | Player identifier. |
| Vec3 pos | Position to be reached. |
| Vec3 angles | . |

docs: y · retail: unconfirmed

### NextLevel

```lua
GameRules.NextLevel()
```

C++: `int NextLevel (IFunctionHandler * pH )`

Loads the next level.

docs: y · retail: unconfirmed

### PerformDeadHit

```lua
GameRules.PerformDeadHit()
```

C++: `int PerformDeadHit (IFunctionHandler* pH )`

Performs a death hit.

docs: y · retail: confirmed (binary)

### ProcessEMPEffect

```lua
GameRules.ProcessEMPEffect(ScriptHandle targetId, float timeScale)
```

Processes the EMP (Electro Magnetic Pulse) effect.

| Param | Description |
|---|---|
| ScriptHandle targetId | Target identifier. |
| float timeScale | Time scale. |

docs: y · retail: unconfirmed

### RegisterHitMaterial

```lua
GameRules.RegisterHitMaterial(const char *materialName)
```

Registers the specified hit material.

| Param | Description |
|---|---|
| const char * materialName | Name of the material. |

docs: y · retail: confirmed (binary)

### RegisterHitType

```lua
GameRules.RegisterHitType(const char *type)
```

Registers a type for the hits.

| Param | Description |
|---|---|
| const char * type | Hit type. |

docs: y · retail: confirmed (binary)

### RemoveMinimapEntity

```lua
GameRules.RemoveMinimapEntity(ScriptHandle entityId)
```

Removes a mipmap entity.

| Param | Description |
|---|---|
| ScriptHandle entityId | Mipmap entity player. |

docs: y · retail: confirmed (binary)

### RemoveObjective

```lua
GameRules.RemoveObjective(int teamId, const char *objective)
```

Removes an objective.

| Param | Description |
|---|---|
| int teamId | Team identifier. |
| const char * objective | Objective name. |

docs: y · retail: unconfirmed

### RemoveSpawnGroup

```lua
GameRules.RemoveSpawnGroup(groupId)
```

Removes spawn group.

| Param | Description |
|---|---|
| ScriptHandle groupId | Group identifier. |

docs: y · retail: confirmed (binary, vanilla×2)

### RemoveSpawnLocation

```lua
GameRules.RemoveSpawnLocation(id)
```

Removes the span location.

| Param | Description |
|---|---|
| ScriptHandle id | Identifier for the script. |

docs: y · retail: confirmed (binary, vanilla×3)

### RemoveSpawnLocationFromSpawnGroup

```lua
GameRules.RemoveSpawnLocationFromSpawnGroup(groupId,location)
```

Removes a spawn location from spawn group.

| Param | Description |
|---|---|
| ScriptHandle groupId | Group identifier. |
| ScriptHandle location | Location. |

docs: y · retail: confirmed (binary, vanilla×1)

### RemoveSpectatorLocation

```lua
GameRules.RemoveSpectatorLocation(ScriptHandle id)
```

Removes a spectator location.

| Param | Description |
|---|---|
| ScriptHandle id | Spectator identifier. |

docs: y · retail: unconfirmed

### RemoveTeam

```lua
GameRules.RemoveTeam(int teamId)
```

Removes the specified team.

| Param | Description |
|---|---|
| int teamId | Team identifier. |

docs: y · retail: confirmed (binary)

### RenamePlayer

```lua
GameRules.RenamePlayer(ScriptHandle playerId, const char *name)
```

Renames the player.

| Param | Description |
|---|---|
| ScriptHandle playerId | Player identifier. |
| const char * name | New name for the player. |

docs: y · retail: unconfirmed

### ResetEntities

```lua
GameRules.ResetEntities()
```

C++: `int ResetEntities (IFunctionHandler * pH )`

docs: y · retail: confirmed (binary)

### ResetGameStartTimer

```lua
GameRules.ResetGameStartTimer()
```

C++: `int ResetGameStartTimer (IFunctionHandler * pH , float time )`

Resets game start timer.

docs: y · retail: unconfirmed

### ResetGameTime

```lua
GameRules.ResetGameTime()
```

C++: `int ResetGameTime (IFunctionHandler * pH )`

Resets the game time.

docs: y · retail: confirmed (binary)

### ResetHitMaterials

```lua
GameRules.ResetHitMaterials()
```

C++: `int ResetHitMaterials (IFunctionHandler * pH )`

Resets the hit materials.

docs: y · retail: confirmed (binary)

### ResetHitTypes

```lua
GameRules.ResetHitTypes()
```

C++: `int ResetHitTypes (IFunctionHandler * pH )`

Resets the hit types.

docs: y · retail: confirmed (binary)

### ResetMinimap

```lua
GameRules.ResetMinimap()
```

C++: `int ResetMinimap (IFunctionHandler * pH )`

docs: y · retail: confirmed (binary)

### ResetObjectives

```lua
GameRules.ResetObjectives()
```

C++: `int ResetObjectives (IFunctionHandler * pH )`

Resets all the objectives.

docs: y · retail: unconfirmed

### ResetPreRoundTime

```lua
GameRules.ResetPreRoundTime()
```

C++: `int ResetPreRoundTime (IFunctionHandler * pH )`

Resets the pre-round time.

docs: y · retail: confirmed (binary)

### ResetReviveCycleTime

```lua
GameRules.ResetReviveCycleTime()
```

C++: `int ResetReviveCycleTime (IFunctionHandler * pH )`

Resets the revive cycle time.

docs: y · retail: confirmed (binary)

### ResetRoundTime

```lua
GameRules.ResetRoundTime()
```

C++: `int ResetRoundTime (IFunctionHandler * pH )`

Resets the round time.

docs: y · retail: confirmed (binary)

### ResetSynchedStorage

```lua
GameRules.ResetSynchedStorage()
```

C++: `int ResetSynchedStorage (IFunctionHandler * pH )`

Resets the sync storage.

docs: y · retail: unconfirmed

### RevivePlayer

```lua
GameRules.RevivePlayer(ScriptHandle playerId, Vec3 pos, Vec3 angles, int teamId, bool clearInventory)
```

Revives the player.

| Param | Description |
|---|---|
| ScriptHandle playerId | Player identifier. |
| Vec3 pos | Player position. |
| Vec3 angles | Player angle. |
| int teamId | Team identifier. |
| bool clearInventory | True to clean the inventory, false otherwise. |

docs: y · retail: unconfirmed

### RevivePlayerInVehicle

```lua
GameRules.RevivePlayerInVehicle(ScriptHandle playerId, ScriptHandle vehicleId, int seatId, int teamId, bool clearInventory)
```

Revives a player inside a vehicle.

| Param | Description |
|---|---|
| ScriptHandle playerId | Player identifier. |
| ScriptHandle vehicleId | Vehicle identifier. |
| int seatId | Seat identifier. |
| int teamId | Team identifier. |
| bool clearInventory | True to clean the inventory, false otherwise. |

docs: y · retail: unconfirmed

### ScheduleEntityRemoval

```lua
GameRules.ScheduleEntityRemoval(ScriptHandle entityId, float timer, bool visibility)
```

Schedules the removal of the specified entity.

| Param | Description |
|---|---|
| ScriptHandle entityId | Entity identifier. |
| float timer | Float value for the time of the entity removal. |
| bool visibility | Removal visibility. |

docs: y · retail: unconfirmed

### ScheduleEntityRespawn

```lua
GameRules.ScheduleEntityRespawn(ScriptHandle entityId, bool unique, float timer)
```

Schedules a respawning of the specified entity.

| Param | Description |
|---|---|
| ScriptHandle entityId | Entity identifier. |
| bool unique | True to have a unique respawn, false otherwise. |
| float timer | Float value for the respawning time. |

docs: y · retail: unconfirmed

### SendChatMessage

```lua
GameRules.SendChatMessage(int type, ScriptHandle sourceId, ScriptHandle targetId, const char *msg)
```

Sends a text message from the source to the target with the specified type and text.

| Param | Description |
|---|---|
| int type | Message type. |
| ScriptHandle sourceId | Source identifier. |
| ScriptHandle targetId | Target identifier. |
| const char * msg | Message string. |

docs: y · retail: unconfirmed

### SendDamageIndicator

```lua
GameRules.SendDamageIndicator(ScriptHandle targetId, ScriptHandle shooterId, ScriptHandle weaponId)
```

Send a damage indicator from the shooter to the target.

| Param | Description |
|---|---|
| ScriptHandle targetId | Target identifier. |
| ScriptHandle shooterId | Shooter identifier. |
| ScriptHandle weaponId | Weapon identifier. |

docs: y · retail: unconfirmed

### SendHitIndicator

```lua
GameRules.SendHitIndicator(ScriptHandle shooterId)
```

Sends a hit indicator.

| Param | Description |
|---|---|
| ScriptHandle shooterId | Shooter identifier. |

docs: y · retail: unconfirmed

### SendTextMessage

```lua
GameRules.SendTextMessage(int type, const char *msg)
```

Sends a text message type with the specified text.

| Param | Description |
|---|---|
| int type | Message type. |
| const char * msg | Message string. |

docs: y · retail: confirmed (binary)

### ServerExplosion

```lua
GameRules.ServerExplosion(ScriptHandle shooterId, ScriptHandle weaponId, float dmg, Vec3 pos, Vec3 dir, float radius, float angle, float pressure, float holesize)
```

C++: `int ServerExplosion (IFunctionHandler * pH , ScriptHandle shooterId , ScriptHandle weaponId , float dmg , Vec3 pos , Vec3 dir , float radius , float angle , float pressure , float holesize )`

docs: y · retail: unconfirmed

### ServerHit

```lua
GameRules.ServerHit(ScriptHandle targetId, ScriptHandle shooterId, ScriptHandle weaponId, float dmg, float radius, int materialId, int partId, int typeId)
```

C++: `int ServerHit (IFunctionHandler * pH , ScriptHandle targetId , ScriptHandle shooterId , ScriptHandle weaponId , float dmg , float radius , int materialId , int partId , int typeId )`

docs: y · retail: confirmed (vanilla×1)

### SetInvulnerability

```lua
GameRules.SetInvulnerability(ScriptHandle playerId, bool invulnerable)
```

Sets/unsets invulnerability for the specified player.

| Param | Description |
|---|---|
| ScriptHandle playerId | Player identifier. |
| bool invulnerable | True to set invulnerability to the player, false to unset. |

docs: y · retail: confirmed (binary, vanilla×3, mod×1)

### SetObjectiveEntity

```lua
GameRules.SetObjectiveEntity(int teamId, const char *objective, ScriptHandle entityId)
```

Sets the objective entity.

| Param | Description |
|---|---|
| int teamId | Team identifier. |
| const char * objective | Objective name. |
| ScriptHandle entityId | Entity identifier. |

docs: y · retail: unconfirmed

### SetObjectiveStatus

```lua
GameRules.SetObjectiveStatus(int teamId, const char *objective, int status)
```

Sets the status of an objective.

| Param | Description |
|---|---|
| int teamId | Team identifier. |
| const char * objective | Objective name. |
| int status | Status. |

docs: y · retail: unconfirmed

### SetPlayerSpawnGroup

```lua
GameRules.SetPlayerSpawnGroup(ScriptHandle playerId, ScriptHandle groupId)
```

Sets the player spawn group.

| Param | Description |
|---|---|
| ScriptHandle playerId | Player identifier. |
| ScriptHandle groupId | Group identifier. |

docs: y · retail: confirmed (binary)

### SetSynchedEntityValue

```lua
GameRules.SetSynchedEntityValue(ScriptHandle entityId, int key)
```

Sets a sync entity value.

| Param | Description |
|---|---|
| ScriptHandle entityId | Entity identifier. |
| int key | Key for the sync entity value. |

docs: y · retail: unconfirmed

### SetSynchedGlobalValue

```lua
GameRules.SetSynchedGlobalValue(int key , value)
```

Sets a sync global value.

| Param | Description |
|---|---|
| int key | Key for the sync global value. |
| value | Value we want to set. The function recognize the type of the value. |

docs: y · retail: unconfirmed

### SetTeam

```lua
GameRules.SetTeam(int teamId, ScriptHandle playerId)
```

Adds a player to a team.

| Param | Description |
|---|---|
| int teamId | Team identifier. |
| ScriptHandle playerId | Player identifier. |

docs: y · retail: confirmed (binary, vanilla×3)

### SetTeamDefaultSpawnGroup

```lua
GameRules.SetTeamDefaultSpawnGroup(int teamId, groupId)
```

Sets the default spawn group for the team.

| Param | Description |
|---|---|
| int teamId | Team identifier. |
| ScriptHandle groupId | Group identifier. |

docs: y · retail: confirmed (binary, vanilla×1)

### ShatterEntity

```lua
GameRules.ShatterEntity(ScriptHandle entityId, Vec3 pos, Vec3 impulse)
```

Shatters an entity.

| Param | Description |
|---|---|
| ScriptHandle entityId | Entity identifier. |
| Vec3 pos | Position vector. |
| Vec3 impulse | Impulse vector for the shattering. |

docs: y · retail: unconfirmed

### SpawnPlayer

```lua
GameRules.SpawnPlayer(int channelId, const char *name, const char *className, Vec3 pos, Vec3 angles)
```

Spawns a player.

| Param | Description |
|---|---|
| int channelId | Channel identifier. |
| const char * name | Player name. |
| const char * className | Name of the player class. |
| Vec3 pos | Player position. |
| Vec3 angles | Player angle. |

docs: y · retail: unconfirmed

### SPNotifyPlayerKill

```lua
GameRules.SPNotifyPlayerKill(ScriptHandle targetId, ScriptHandle weaponId, bool bHeadShot)
```

Notifies that the player kills somebody.

| Param | Description |
|---|---|
| ScriptHandle targetId | Target identifier. |
| ScriptHandle weaponId | Weapon identifier. |
| bool bHeadShot | True if the shot was to the head of the target, false otherwise. |

docs: y · retail: unconfirmed

### TextMessage

```lua
GameRules.TextMessage()
```

Displays a text message type with the specified text.

| Param | Description |
|---|---|
| int type | Message type. |
| const char * msg | Message string. |

docs: y · retail: confirmed (binary)
