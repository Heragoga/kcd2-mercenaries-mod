# Dice

C++ class(es): `C_ScriptBind_Dice`
Reached from Lua as `Dice.FunctionName(...)`.
9 documented function(s); 0 additional undocumented function(s) found in retail/runtime.

## Functions

### GetDice

```lua
Dice.GetDice()
```

C++: `C_Dice& GetDice ()`

docs: y · retail: unconfirmed

### HoldDie

```lua
Dice.HoldDie()
```

C++: `int HoldDie (IFunctionHandler* fh , ScriptHandle userId , ScriptHandle dieEntityId , int dieNumber , int hold )`

docs: y · retail: confirmed (runtime dump)

### OverrideNextThrow

```lua
Dice.OverrideNextThrow()
```

C++: `int OverrideNextThrow (IFunctionHandler* fh , int player , SmartScriptTable tbl )`

docs: y · retail: confirmed (runtime dump)

### RollDie

```lua
Dice.RollDie(dieNumber)
```

Rolls a single die.

| Param | Description |
|---|---|
| int dieNumber | number of the die (0 - 5) |

docs: y · retail: confirmed (binary, runtime dump)

### SetAdvantage

```lua
Dice.SetAdvantage()
```

C++: `int SetAdvantage (IFunctionHandler* fh , int player , float advantage )`

docs: y · retail: confirmed (runtime dump)

### SetAIDifficulty

```lua
Dice.SetAIDifficulty()
```

C++: `int SetAIDifficulty (IFunctionHandler* fh , float difficulty )`

docs: y · retail: confirmed (binary, runtime dump)

### SetAIRiskTaking

```lua
Dice.SetAIRiskTaking()
```

C++: `int SetAIRiskTaking (IFunctionHandler* fh , float riskTaking )`

docs: y · retail: confirmed (binary, runtime dump)

### SetScore

```lua
Dice.SetScore()
```

C++: `int SetScore (IFunctionHandler* fh , int player1Total , int player2Total )`

docs: y · retail: confirmed (runtime dump)

### ToggleHoldDie

```lua
Dice.ToggleHoldDie()
```

C++: `int ToggleHoldDie (IFunctionHandler* fh , ScriptHandle userId , ScriptHandle dieEntityId , int dieNumber )`

docs: y · retail: confirmed (binary, runtime dump)
