# HitDeathReactions

C++ class(es): `CScriptBindHitDeathReactions`, `CScriptBind_HitDeathReactions`
Reached from Lua as `HitDeathReactions.FunctionName(...)`.
9 documented function(s); 0 additional undocumented function(s) found in retail/runtime.

## Functions

### EndCurrentReaction

```lua
HitDeathReactions.EndCurrentReaction()
```

C++: `int EndCurrentReaction (IFunctionHandler * pH )`

Ends the current reaction

docs: y · retail: unconfirmed

### EndReactionAnim

```lua
HitDeathReactions.EndReactionAnim()
```

C++: `int EndReactionAnim (IFunctionHandler * pH )`

Ends the current reaction anim, if any

docs: y · retail: unconfirmed

### ExecuteDeathReaction

```lua
HitDeathReactions.ExecuteDeathReaction()
```

C++: `int ExecuteDeathReaction (IFunctionHandler * pH , SmartScriptTable reactionParams )`

Executes a death reaction using the default C++ execution code Params: reactionParams = script table with the reaction parameters

docs: y · retail: unconfirmed

### ExecuteHitReaction

```lua
HitDeathReactions.ExecuteHitReaction()
```

C++: `int ExecuteHitReaction (IFunctionHandler * pH , SmartScriptTable reactionParams )`

Executes a hit reaction using the default C++ execution code Params: reactionParams = script table with the reaction parameters

docs: y · retail: unconfirmed

### GetMemoryUsage

```lua
HitDeathReactions.GetMemoryUsage()
```

C++: `virtual void GetMemoryUsage (ICrySizer * pSizer ) const`

This is GetMemoryUsage, a member of class CScriptBind_HitDeathReactions.

docs: y · retail: unconfirmed

### IsValidReaction

```lua
HitDeathReactions.IsValidReaction()
```

C++: `int IsValidReaction (IFunctionHandler * pH , SmartScriptTable validationParams , SmartScriptTable scriptHitInfo )`

Run the default C++ validation code and returns its result Params: validationParams = script table with the validation parameters scriptHitInfo = script table with the hit info Return: TRUE is the validation was successful, FALSE otherwise

docs: y · retail: unconfirmed

### OnHit

```lua
HitDeathReactions.OnHit()
```

C++: `int OnHit (IFunctionHandler * pH , SmartScriptTable scriptHitInfo , float fCausedDamage = 0.0f)`

Notifies a hit event to the hit death reactions system Params: scriptHitInfo = script table with the hit info

Return: TRUE if the hit is processed successfully, FALSE otherwise

docs: y · retail: confirmed (vanilla×16)

### StartInteractiveAction

```lua
HitDeathReactions.StartInteractiveAction()
```

C++: `int StartInteractiveAction (IFunctionHandler * pH , const char * szActionName )`

Starts an interactive action. Params: szActionName = name of the interactive action

docs: y · retail: unconfirmed

### StartReactionAnim

```lua
HitDeathReactions.StartReactionAnim()
```

C++: `int StartReactionAnim (IFunctionHandler * pH )`

Starts an animation through the HitDeathReactions. Pauses the animation graph while playing it and resumes automatically when the animation ends Params: (sAnimName, bool bLoop = false, float fBlendTime = 0.2f, int iSlot = 0, int iLayer = 0, float fAniSpeed = 1.0f)

docs: y · retail: unconfirmed
