# Tutorial

C++ class(es): `C_ScriptBindTutorial`
Reached from Lua as `Tutorial.FunctionName(...)`.
6 documented function(s); 0 additional undocumented function(s) found in retail/runtime.

## Functions

### Complete

```lua
Tutorial.Complete()
```

C++: `virtual int Complete (IFunctionHandler* pH , char const * pName )`

Completes tutorial.

docs: y · retail: unconfirmed

### GetStage

```lua
Tutorial.GetStage()
```

C++: `virtual int GetStage (IFunctionHandler* pH , char const * pName )`

Returns current tutorial progress stage

docs: y · retail: unconfirmed

### IsActive

```lua
Tutorial.IsActive()
```

C++: `virtual int IsActive (IFunctionHandler* pH , char const * pName )`

Return true in case tutorial is in progress.

docs: y · retail: confirmed (binary, vanilla×1)

### IsComplete

```lua
Tutorial.IsComplete()
```

C++: `virtual int IsComplete (IFunctionHandler* pH , char const * pName )`

Returns true in case tutorial is completed.

docs: y · retail: unconfirmed

### Proceed

```lua
Tutorial.Proceed()
```

C++: `virtual int Proceed (IFunctionHandler* pH , char const * pName )`

Proceed to next tutorial stage.

docs: y · retail: unconfirmed

### Restart

```lua
Tutorial.Restart()
```

C++: `virtual int Restart (IFunctionHandler* pH , char const * pName )`

Restarts tutorial.

docs: y · retail: unconfirmed
