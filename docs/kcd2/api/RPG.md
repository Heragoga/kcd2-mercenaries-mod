# RPG

C++ class(es): `C_ScriptBindRPGModule`, `C_ScriptBind_RPG`, `C_ScriptBind_RPGModule`
Reached from Lua as `RPG.FunctionName(...)`.
34 documented function(s); 1 additional undocumented function(s) found in retail/runtime.

## Functions

### _GetConstant

```lua
RPG._GetConstant()
```

C++: `int _GetConstant (IFunctionHandler * h , SmartScriptTable table , const char * key )`

This is _GetConstant, a member of class C_ScriptBind_RPGModule.

docs: y · retail: confirmed (runtime dump)

### _SetConstant

```lua
RPG._SetConstant()
```

C++: `int _SetConstant (IFunctionHandler * h , SmartScriptTable table , const char * key , float value )`

This is _SetConstant, a member of class C_ScriptBind_RPGModule.

docs: y · retail: unconfirmed

### AddLocationPoint

```lua
RPG.AddLocationPoint(entityId)
```

C++: `int AddLocationPoint (IFunctionHandler* pH , ScriptHandle entityId )`

Registers location point entity into entity manager

docs: y · retail: confirmed (binary, runtime dump, vanilla×2 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/WH/LocationPoint.lua`))

### AddStatXP

```lua
RPG.AddStatXP(event, soul, statName, totalXp, oldProgress, newProgress)
```

C++: `int AddStatXP (IFunctionHandler* h , ScriptHandle rpgEvent , framework::T_WUIDScriptType soulId , const char * statName , int totalXp , float oldProgress , float newProgress )`

Gives soul 'soul' X XP points towards RPG stat 'statName' (e.g. 'str' for strength, 'agi' for agility), where 'X = floor(totalXp * newProgress) - floor(totalXp * oldProgress)'.

docs: y · retail: confirmed (binary, runtime dump)

### AttachTo

```lua
RPG.AttachTo()
```

C++: `void AttachTo (entitymodule::C_Actor &)`

This is AttachTo, a member of class C_ScriptBind_RPG.

docs: y · retail: unconfirmed

### CaptionObjectUsed

```lua
RPG.CaptionObjectUsed()
```

C++: `int CaptionObjectUsed (IFunctionHandler* h , ScriptHandle captionObjectEntityId )`

This is CaptionObjectUsed, a member of class C_ScriptBindRPGModule.

docs: y · retail: confirmed (runtime dump, vanilla×1 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/WH/Others/CaptionObject.lua`))

### DetachFrom

```lua
RPG.DetachFrom()
```

C++: `void DetachFrom (entitymodule::C_Actor &)`

This is DetachFrom, a member of class C_ScriptBind_RPG.

docs: y · retail: unconfirmed

### GetFactionById

```lua
RPG.GetFactionById(factionId)
```

Returns faction with the given id or nil if no such faction exists.

| Param | Description |
|---|---|
| const char* factionId | string id of a faction |

docs: y · retail: confirmed (binary, runtime dump)

### GetFactions

```lua
RPG.GetFactions()
```

C++: `int GetFactions (IFunctionHandler* h )`

Rerturns an array of all factions.

docs: y · retail: confirmed (binary, runtime dump)

### GetGatherMult

```lua
rpg.GetGatherMult(ScriptHandle id)
```

C++: `int GetGatherMult (IFunctionHandler * h )`

gets gather skill multiplier

docs: y · retail: confirmed (binary)

### GetHerbCollectingEfficiency

```lua
RPG.GetHerbCollectingEfficiency()
```

C++: `int GetHerbCollectingEfficiency (IFunctionHandler * h , ScriptHandle collectorEntityId )`

Returns a real number in interval [0,1]

docs: y · retail: unconfirmed

### GetHobbies

```lua
RPG.GetHobbies()
```

C++: `int GetHobbies (IFunctionHandler * h )`

Returns a table indexed by hobby names.

docs: y · retail: unconfirmed

### GetIndulgencePrice

```lua
RPG.GetIndulgencePrice()
```

C++: `int GetIndulgencePrice (IFunctionHandler* h )`

Returns indulgence price in decigroschen. 0 means no indulgence necessary -- all public friends are at or above their base reputation value.

docs: y · retail: confirmed (binary, runtime dump, vanilla×2 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/WH/Triggers/IndulgenceBoxTrigger.lua`))

### GetLocationById

```lua
RPG.GetLocationById()
```

Returns a location object or nil.

| Param | Description |
|---|---|
| const char* locationId | GUID of the location as string |

docs: y · retail: confirmed (binary, runtime dump)

### GetLocationByName

```lua
RPG.GetLocationByName()
```

Returns a location object or nil.

| Param | Description |
|---|---|
| const char* locationName | name of the location as string |

docs: y · retail: confirmed (binary, runtime dump)

### GetLocations

```lua
RPG.GetLocations()
```

C++: `int GetLocations (IFunctionHandler* h )`

Returns an array of all locations.

docs: y · retail: confirmed (binary, runtime dump, mod×6)

### GetMemoryUsage

```lua
RPG.GetMemoryUsage()
```

C++: `virtual void GetMemoryUsage (ICrySizer * pSizer ) const`

This is GetMemoryUsage, a member of class C_ScriptBind_RPGModule.

docs: y · retail: unconfirmed

### GetSoulStats

```lua
RPG.GetSoulStats()
```

C++: `rpglib::S_SoulStats * GetSoulStats (IFunctionHandler * h )`

This is GetSoulStats, a member of class C_ScriptBind_RPG.

docs: y · retail: unconfirmed

### Help

```lua
RPG.Help()
```

C++: `int Help (IFunctionHandler * h )`

Print RPG constants/params with their values. You can supply one string argument to filter the results.

docs: y · retail: unconfirmed

### IsPublicEnemy

```lua
RPG.IsPublicEnemy(wuid)
```

C++: `int IsPublicEnemy (IFunctionHandler * pH , framework::T_WUIDScriptType wuid )`

Returns if soul represented by wuid is public enemy.

docs: y · retail: confirmed (binary, runtime dump, vanilla×1 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/WH/Stash/AnimStash.lua`), mod×4)

### NotifyLevelXpGain

```lua
RPG.NotifyLevelXpGain()
```

C++: `int NotifyLevelXpGain (IFunctionHandler* h , const char * skill )`

This is NotifyLevelXpGain, a member of class C_ScriptBindRPGModule.

docs: y · retail: confirmed (binary, runtime dump)

### Release

```lua
RPG.Release()
```

C++: `void Release ()`

This is Release, a member of class C_ScriptBind_RPGModule.

docs: y · retail: unconfirmed

### SetAgility

```lua
rpg.SetAgility(ScriptHandle id, value)
```

sets Agility to new value

| Param | Description |
|---|---|
| float value | value to set |

docs: y · retail: unconfirmed

### SetCurrStamina

```lua
rpg.SetCurrStamina(ScriptHandle id, value)
```

sets CurrStamina to new value

| Param | Description |
|---|---|
| float value | value to set |

docs: y · retail: unconfirmed

### SetDeathReason

```lua
rpg.SetDeathReason(ScriptHandle id, int value)
```

sets DeathReason to new value

| Param | Description |
|---|---|
| int value | value to set from enum E_DeathReason |

docs: y · retail: unconfirmed

### SetFood

```lua
rpg.SetFood(ScriptHandle id, value)
```

sets Food to new value

| Param | Description |
|---|---|
| float value | value to set 0.0f-120.0f |

docs: y · retail: unconfirmed

### SetHealth

```lua
rpg.SetHealth(ScriptHandle id, value)
```

sets health to new value

| Param | Description |
|---|---|
| float value | hp to set 0.0f-100.0f |

docs: y · retail: confirmed (mod×12)

### SetMaxStamina

```lua
rpg.SetMaxStamina(ScriptHandle id, value)
```

sets MaxStamina to new value

| Param | Description |
|---|---|
| float value | value to set |

docs: y · retail: unconfirmed

### SetStrength

```lua
rpg.SetStrength(ScriptHandle id, value)
```

sets Strength to new value

| Param | Description |
|---|---|
| float value | value to set |

docs: y · retail: unconfirmed

### SetToHeal

```lua
rpg.SetToHeal(ScriptHandle id, value)
```

sets ToHeal to new value

| Param | Description |
|---|---|
| float value | value to set |

docs: y · retail: unconfirmed

### SetVigour

```lua
rpg.SetVigour(ScriptHandle id, value)
```

sets Vigour to new value

| Param | Description |
|---|---|
| float value | value to set |

docs: y · retail: unconfirmed

### SetVitality

```lua
rpg.SetVitality(ScriptHandle id, value)
```

sets Vitality to new value

| Param | Description |
|---|---|
| float value | value to set |

docs: y · retail: unconfirmed

### UnlockAllRecipes

```lua
RPG.UnlockAllRecipes()
```

Unlocks all recipes with all steps.

| Param | Description |
|---|---|
| ScriptHandle userId | entity id of soul who is unlocking recipes |

docs: y · retail: unconfirmed

### UnlockRecipeStep

```lua
RPG.UnlockRecipeStep()
```

Unlocks recipe step.

| Param | Description |
|---|---|
| ScriptHandle userId | entity id of soul who is unlocking recipe |
| int recipeId | id of recipe to unlock |
| int stepId | id of step to unlock, 0 for unlocking all steps in recipes |

docs: y · retail: unconfirmed

## Undocumented (present in retail, not in official docs)

### ReconcileWithPublicFriends

`RPG.ReconcileWithPublicFriends(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (binary, runtime dump, vanilla×1 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/WH/Triggers/IndulgenceBoxTrigger.lua`))
