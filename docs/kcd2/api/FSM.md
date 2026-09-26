# FSM

C++ class(es): `C_ScriptBindFSM`
Reached from Lua as `FSM.FunctionName(...)`.
27 documented function(s); 0 additional undocumented function(s) found in retail/runtime.

## Functions

### AIAnimEx

```lua
FSM.AIAnimEx()
```

C++: `int AIAnimEx (IFunctionHandler * pH , char const * animGraphSignalValue , bool isOneShot , Vec3 position , float posTolerance , Vec3 direction , float dirTolerance )`

docs: y · retail: unconfirmed

### AIGoto

```lua
FSM.AIGoto()
```

C++: `int AIGoto (IFunctionHandler * pH , Vec3 vec3Param )`

WH_CTSW(WH_CTSW_MASTER)

docs: y · retail: unconfirmed

### BlackBoardDelete

```lua
FSM.BlackBoardDelete()
```

C++: `int BlackBoardDelete (IFunctionHandler * pH , char const * soulName , char const * key )`

docs: y · retail: unconfirmed

### BlackBoardExists

```lua
FSM.BlackBoardExists()
```

C++: `int BlackBoardExists (IFunctionHandler * pH , char const * soulName , char const * key )`

docs: y · retail: unconfirmed

### BlackBoardGetFloat

```lua
FSM.BlackBoardGetFloat()
```

C++: `int BlackBoardGetFloat (IFunctionHandler * pH , char const * soulName , char const * key )`

docs: y · retail: unconfirmed

### BlackBoardGetInt

```lua
FSM.BlackBoardGetInt()
```

C++: `int BlackBoardGetInt (IFunctionHandler * pH , char const * soulName , char const * key )`

docs: y · retail: unconfirmed

### BlackBoardGetString

```lua
FSM.BlackBoardGetString()
```

C++: `int BlackBoardGetString (IFunctionHandler * pH , char const * soulName , char const * key )`

docs: y · retail: unconfirmed

### BlackBoardSetFloat

```lua
FSM.BlackBoardSetFloat()
```

C++: `int BlackBoardSetFloat (IFunctionHandler * pH , char const * soulName , char const * key , float value )`

docs: y · retail: unconfirmed

### BlackBoardSetInt

```lua
FSM.BlackBoardSetInt()
```

C++: `int BlackBoardSetInt (IFunctionHandler * pH , char const * soulName , char const * key , int value )`

docs: y · retail: unconfirmed

### BlackBoardSetString

```lua
FSM.BlackBoardSetString()
```

C++: `int BlackBoardSetString (IFunctionHandler * pH , char const * soulName , char const * key , char const * string )`

blackboard of a soul

docs: y · retail: unconfirmed

### CallScript

```lua
FSM.CallScript()
```

C++: `bool CallScript ( char const * name , C_Soul&, char const * ruleParam )`

docs: y · retail: unconfirmed

### FSMFunctionWithParam0

```lua
FSM.FSMFunctionWithParam0()
```

C++: `int FSMFunctionWithParam0 (IFunctionHandler * pH )`

test functions

test of binding

docs: y · retail: unconfirmed

### FSMFunctionWithParam1

```lua
FSM.FSMFunctionWithParam1()
```

C++: `int FSMFunctionWithParam1 (IFunctionHandler * pH , int intParam )`

docs: y · retail: unconfirmed

### FSMFunctionWithParam1String

```lua
FSM.FSMFunctionWithParam1String()
```

C++: `int FSMFunctionWithParam1String (IFunctionHandler * pH , char const * stringParam )`

docs: y · retail: unconfirmed

### FSMFunctionWithParam2

```lua
FSM.FSMFunctionWithParam2()
```

C++: `int FSMFunctionWithParam2 (IFunctionHandler * pH , ScriptHandle ptrParam , int flags )`

docs: y · retail: unconfirmed

### FSMFunctionWithParam3

```lua
FSM.FSMFunctionWithParam3()
```

C++: `int FSMFunctionWithParam3 (IFunctionHandler * pH , int intParam , Vec3 vec3Param , float floatParam )`

docs: y · retail: unconfirmed

### LoadScripts

```lua
FSM.LoadScripts()
```

C++: `bool LoadScripts ( char const * path , bool forceReload )`

docs: y · retail: unconfirmed

### MyBlackBoardDelete

```lua
FSM.MyBlackBoardDelete()
```

C++: `int MyBlackBoardDelete (IFunctionHandler * pH , char const * key )`

docs: y · retail: unconfirmed

### MyBlackBoardExists

```lua
FSM.MyBlackBoardExists()
```

C++: `int MyBlackBoardExists (IFunctionHandler * pH , char const * key )`

docs: y · retail: unconfirmed

### MyBlackBoardGetFloat

```lua
FSM.MyBlackBoardGetFloat()
```

C++: `int MyBlackBoardGetFloat (IFunctionHandler * pH , char const * key )`

docs: y · retail: unconfirmed

### MyBlackBoardGetInt

```lua
FSM.MyBlackBoardGetInt()
```

C++: `int MyBlackBoardGetInt (IFunctionHandler * pH , char const * key )`

docs: y · retail: unconfirmed

### MyBlackBoardGetString

```lua
FSM.MyBlackBoardGetString()
```

C++: `int MyBlackBoardGetString (IFunctionHandler * pH , char const * key )`

docs: y · retail: unconfirmed

### MyBlackBoardSetFloat

```lua
FSM.MyBlackBoardSetFloat()
```

C++: `int MyBlackBoardSetFloat (IFunctionHandler * pH , char const * key , float value )`

docs: y · retail: unconfirmed

### MyBlackBoardSetInt

```lua
FSM.MyBlackBoardSetInt()
```

C++: `int MyBlackBoardSetInt (IFunctionHandler * pH , char const * key , int value )`

docs: y · retail: unconfirmed

### MyBlackBoardSetString

```lua
FSM.MyBlackBoardSetString()
```

C++: `int MyBlackBoardSetString (IFunctionHandler * pH , char const * key , char const * string )`

blackboard of the current soul

docs: y · retail: unconfirmed

### PlayAnimation

```lua
FSM.PlayAnimation()
```

C++: `int PlayAnimation (IFunctionHandler * pH , char const * animationName )`

docs: y · retail: unconfirmed

### SetSoulList

```lua
FSM.SetSoulList()
```

C++: `void SetSoulList (C_SoulList&)`

docs: y · retail: unconfirmed
