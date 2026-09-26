# Backgammon

C++ class(es): `C_ScriptBindBackgammon`, `C_ScriptBind_Backgammon`
Reached from Lua as `Backgammon.FunctionName(...)`.
7 documented function(s); 0 additional undocumented function(s) found in retail/runtime.

## Functions

### AcceptGame

```lua
Backgammon.AcceptGame(EntityGUID opponentId, EntityGUID playerId)
```

Opponent accepted previous request.

| Param | Description |
|---|---|
| playerId | entity id of opponent who accepts the request |
| opponentId | entity id of player who requested the game |

docs: y · retail: unconfirmed

### EndGame

```lua
Backgammon.EndGame(EntityGUID playerId)
```

Player requests game end.

| Param | Description |
|---|---|
| playerId | entity id of player who requests the game end |

docs: y · retail: confirmed (binary)

### MoveChecker

```lua
Backgammon.MoveChecker(EntityGUID playerId, int pointFrom, int pointTo)
```

Player requires move from point to point.

| Param | Description |
|---|---|
| int pointFrom | point from which move will be made |
| int pointTo | point where move will be made |
| playerId | entity id of player who requests the move of checker |

docs: y · retail: unconfirmed

### OfferBet

```lua
Backgammon.OfferBet(EntityGUID playerId, int money)
```

Player offers his bet for current game.

| Param | Description |
|---|---|
| int money | how much player bets |
| playerId | entity id of player who offers the bet |

docs: y · retail: unconfirmed

### RequestGame

```lua
Backgammon.RequestGame(EntityGUID playerId, EntityGUID opponentId, EntityGUID boardId)
```

Player requests new game with an opponent.

| Param | Description |
|---|---|
| playerId | entity id of player who requests the game |
| opponentId | entity id of opponent who should accept the request |
| boardId | entity id of board used for the game |

docs: y · retail: unconfirmed

### RollDice

```lua
Backgammon.RollDice(EntityGUID playerId)
```

Player rolled the dice.

| Param | Description |
|---|---|
| playerId | entity id of player who rolled the dice boolParam(optional) - true, either if it is first roll with single dice or if player wants cheat |

docs: y · retail: unconfirmed

### RolledDice

```lua
Backgammon.RolledDice(EntityGUID playerId)
```

Player finished rolling the dice.

| Param | Description |
|---|---|
| playerId | entity id of player who rolled the dice |

docs: y · retail: unconfirmed
