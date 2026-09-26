# ShootingContest

C++ class(es): `C_ScriptBind_ShootingContest`
Reached from Lua as `ShootingContest.FunctionName(...)`.
8 documented function(s); 0 additional undocumented function(s) found in retail/runtime.

## Functions

### HideHorseShootingContestTable

```lua
ShootingContest.HideHorseShootingContestTable()
```

C++: `int HideHorseShootingContestTable (IFunctionHandler* pH )`

Hide table ui for horse contest

docs: y · retail: confirmed (runtime dump)

### HideShootingContestTable

```lua
ShootingContest.HideShootingContestTable()
```

C++: `int HideShootingContestTable (IFunctionHandler* pH )`

Hide table ui for contest

docs: y · retail: confirmed (runtime dump)

### SetUI

```lua
ShootingContest.SetUI()
```

C++: `void SetUI (I_UIShootingContest* ui )`

docs: y · retail: unconfirmed

### ShowHorseShootingContestTable

```lua
ShootingContest.ShowHorseShootingContestTable(playerName, opponentName, playerScore, opponentScore, trackName)
```

C++: `int ShowHorseShootingContestTable (IFunctionHandler* pH , const char * playerName , const char * opponentName , int playerScore , int opponentScore , const char * trackName )`

Show table ui for horse contest, names should be without @

docs: y · retail: confirmed (runtime dump)

### ShowShootingContestTable

```lua
ShootingContest.ShowShootingContestTable(playerName, opponentName1, opponentName2, playerArrows, opponentArrows1, opponentArrows2, isTargetVisible)
```

C++: `int ShowShootingContestTable (IFunctionHandler* pH , const char * playerName , const char * opponentName1 , const char * opponentName2 , int playerArrows , int opponentArrows1 , int opponentArrows2 , bool isTargetVisible )`

Show table ui for contest, names should be without @, empty opponent name mean there is no opponent

docs: y · retail: confirmed (runtime dump)

### ShowShootingHit

```lua
ShootingContest.ShowShootingHit(xPos, yPos)
```

C++: `int ShowShootingHit (IFunctionHandler* pH , float xPos , float yPos )`

Arguments in relative space -1 to 1

docs: y · retail: confirmed (runtime dump)

### UpdateHorseShootingContestTable

```lua
ShootingContest.UpdateHorseShootingContestTable(playerScore)
```

C++: `int UpdateHorseShootingContestTable (IFunctionHandler* pH , int playerScore )`

Update score in ui

docs: y · retail: confirmed (runtime dump)

### UpdateShootingContestTable

```lua
ShootingContest.UpdateShootingContestTable(playerArrows, opponentArrows1, opponentArrows2, playerPoints, opponentArrows1, opponentPoints1, opponentPoints2)
```

C++: `int UpdateShootingContestTable (IFunctionHandler* pH , int playerArrows , int opponentArrows1 , int opponentArrows2 , int playerPoints , int opponentPoints1 , int opponentPoints2 )`

Update score in ui, opponentArrows1 < 0 mean there is no opponent1

docs: y · retail: confirmed (runtime dump)
