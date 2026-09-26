# Soul

C++ class(es): `C_ScriptBindSoul`, `C_ScriptBind_Soul`
Reached from Lua as `Soul.FunctionName(...)`.
94 documented function(s); 0 additional undocumented function(s) found in retail/runtime.

## Functions

### AddBuff

```lua
soul.AddBuff(string buff_id, string perk_id)
```

Adds buff identified by the database id. Returns the instance id. If the buff is the result of a perk, optional perk_id can be used to notify GUI.

| Param | Description |
|---|---|
| const char * perk_id = nullptr | = nullptr |

docs: y · retail: confirmed (binary, vanilla×12, mod×8)

### AddInjury

```lua
soul.AddInjury(1, 'head')
```

C++: `int AddInjury (IFunctionHandler* h , float injury , const char * bodyPartName )`

add [0,1] injury to a body part, bodyPartName from the database

docs: y · retail: unconfirmed

### AddMetaRole

```lua
soul.AddMetaRole(id)
```

C++: `int AddMetaRole (IFunctionHandler * h , T_MetaRoleId id )`

Adds a metarole ids to this soul.

docs: y · retail: unconfirmed

### AddMetaRoleByName

```lua
soul.AddMetaRoleByName(name)
```

C++: `int AddMetaRoleByName (IFunctionHandler * h , char const * pMetaroleName )`

Adds a metarole by its name to this soul.

docs: y · retail: confirmed (binary, vanilla×1)

### AddPerk

```lua
soul.AddPerk(string perk_id)
```

C++: `int AddPerk (IFunctionHandler * h , const char * perk_id )`

Adds perk identified by the database id. Returns the instance id.

docs: y · retail: confirmed (binary, vanilla×2)

### AddSkillXP

```lua
soul.AddSkillXP(string skill, float xp)
```

C++: `int AddSkillXP (IFunctionHandler * h , const char * skill , T_SoulXPValue xp )`

Adds experience points. Returns how many levels had been reached (0 if no level was reached).

docs: y · retail: confirmed (binary)

### AddStatXP

```lua
soul.AddStatXP(string stat, float xp)
```

C++: `int AddStatXP (IFunctionHandler * h , const char * stat , T_SoulXPValue xp )`

Adds experience points. Returns how many levels had been reached (0 if no level was reached).

docs: y · retail: confirmed (binary)

### AddXP

```lua
Soul.AddXP()
```

C++: `template class Enum_T> int AddXP (IFunctionHandler * h , const char * selectorName , T_SoulXPValue xp )`

docs: y · retail: unconfirmed

### AdvanceToSkillLevel

```lua
soul.AdvanceToSkillLevel(string skill, float level)
```

C++: `int AdvanceToSkillLevel (IFunctionHandler * h , const char * skill , T_SoulLvlValue level )`

Set skill level using string name (use skill_name from database). The function will perform correct transition (it will add XPs). Cannot lower the level.

docs: y · retail: confirmed (binary, vanilla×2)

### AdvanceToStatLevel

```lua
soul.AdvanceToStatLevel(string stat, float level)
```

C++: `int AdvanceToStatLevel (IFunctionHandler * h , const char * stat , T_SoulLvlValue level )`

sets stat level, for example soul:AdvanceToStatLevel('str', 20), it will add xp. Cannot lower the level.

docs: y · retail: confirmed (binary, vanilla×1)

### AttachTo

```lua
Soul.AttachTo()
```

C++: `void AttachTo (IEntity & entity , C_Soul & soul )`

This is AttachTo, a member of class C_ScriptBind_Soul.

docs: y · retail: unconfirmed

### CanEatItem

```lua
soul.CanEatItem("89dada87-6e6c-5d2c-a17a-483ada14b90b")
```

C++: `int CanEatItem (IFunctionHandler* h , const char * itemClassIdDef )`

Checks if soul can eat the specified item class. Return true if so, false otherwise.

docs: y · retail: confirmed (binary, vanilla×1)

### DealDamage

```lua
soul.DealDamage(stamina, health, attackerId = invalid, suppressHitreaction = false, bodyPart = null)
```

C++: `int DealDamage (IFunctionHandler * h , float staminaDmg , float healthDmg )`

Causes the soul to loose given stamina and health. Negative values are accepted and treated as a heal. BodyParts are passed by name (from the database).

docs: y · retail: confirmed (vanilla×1)

### DetachFrom

```lua
Soul.DetachFrom()
```

C++: `void DetachFrom (entitymodule::C_Actor &)`

This is DetachFrom, a member of class C_ScriptBind_Soul.

docs: y · retail: unconfirmed

### EatItem

```lua
soul.EatItem("89dada87-6e6c-5d2c-a17a-483ada14b90b")
```

C++: `int EatItem (IFunctionHandler* h , const char * itemClassIdDef )`

Tries to eat an instance of the specified item class. Returns true if the item has been eaten (this includes checking if the item can be eaten), returns false otherwise.

docs: y · retail: confirmed (binary, vanilla×1)

### EnablePerkLeveling

```lua
soul.EnablePerkLeveling(bool enable)
```

C++: `int EnablePerkLeveling (IFunctionHandler * h , bool enable )`

Enables/disables perk leveling.

docs: y · retail: unconfirmed

### GenerateCompanionEventDebug

```lua
soul.GenerateCompanionEventDebug()
```

C++: `int GenerateCompanionEventDebug (IFunctionHandler * h )`

sends a play event for the primary dog companion. Just for debug.

docs: y · retail: unconfirmed

### GetAgility

```lua
soul.GetAgility()
```

C++: `int GetAgility (IFunctionHandler * h )`

gets the agility stat

docs: y · retail: unconfirmed

### GetArchetype

```lua
soul.GetArchetype()
```

C++: `int GetArchetype (IFunctionHandler * h )`

Returns a table containing the archetype properties.

docs: y · retail: confirmed (binary, vanilla×2)

### GetAverageSuperFaction

```lua
soul.GetAverageSuperFaction()
```

C++: `int GetAverageSuperFaction (IFunctionHandler* pH )`

Returns average super faction from all cloths for this soul.

docs: y · retail: unconfirmed

### GetCurrStamina

```lua
soul.GetCurrStamina()
```

C++: `int GetCurrStamina (IFunctionHandler * h )`

gets percentage of stamina

docs: y · retail: unconfirmed

### GetDerivedStat

```lua
soul.GetDerivedStat(string stat, table context, table outUsedPerks)
```

C++: `int GetDerivedStat (IFunctionHandler * h , const char * derivedStat )`

returns current value of a derived stat given by the shortcut name (cha, ...)

docs: y · retail: confirmed (vanilla×3)

### GetFactionID

```lua
soul.GetFactionID()
```

C++: `int GetFactionID (IFunctionHandler * h )`

Returns the ID of the faction that the soul belongs to.

docs: y · retail: confirmed (binary, vanilla×2, mod×2)

### GetFood

```lua
soul.GetFood()
```

C++: `int GetFood (IFunctionHandler * h )`

Amount of food 0..120.

docs: y · retail: unconfirmed

### GetGatherMult

```lua
soul.GetGatherMult(ScriptHandle id)
```

C++: `int GetGatherMult (IFunctionHandler * h )`

gets gather skill multiplier

docs: y · retail: confirmed (binary)

### GetGender

```lua
soul.GetGender()
```

C++: `int GetGender (IFunctionHandler * h )`

Returns soul gender.

docs: y · retail: confirmed (binary, vanilla×3)

### GetHealth

```lua
soul.GetHealth()
```

C++: `int GetHealth (IFunctionHandler * h )`

gets health 0..100

docs: y · retail: confirmed (vanilla×4, mod×6)

### GetHobbies

```lua
soul.GetHobbies()
```

C++: `int GetHobbies (IFunctionHandler * h )`

Returns a table containing all soul's hobbies.

docs: y · retail: unconfirmed

### GetId

```lua
soul.GetId()
```

C++: `int GetId (IFunctionHandler * h )`

Returns unique and persistent id of this soul (WUID).

docs: y · retail: confirmed (binary, vanilla×2, mod×12)

### GetMemoryUsage

```lua
Soul.GetMemoryUsage()
```

C++: `virtual void GetMemoryUsage (ICrySizer * pSizer ) const`

This is GetMemoryUsage, a member of class C_ScriptBind_Soul.

docs: y · retail: unconfirmed

### GetMetaRoles

```lua
soul.GetMetaRoles()
```

C++: `int GetMetaRoles (IFunctionHandler * h )`

Returns a table=array containing metarole ids.

docs: y · retail: confirmed (binary, mod×1)

### GetNameString

```lua
soul.GetNameString()
```

C++: `int GetNameStringId (IFunctionHandler * h )`

returns value of name_string_id column from soul db table

docs: y · retail: unconfirmed

### GetNextLevelSkillXP

```lua
soul.GetNextLevelSkillXP(string skill, uint level)
```

C++: `int GetNextLevelSkillXP (IFunctionHandler * h , const char * skill , unsigned level )`

How many XP points is required for going from the level to level + 1.

docs: y · retail: confirmed (binary)

### GetNextLevelStatXP

```lua
soul.GetNextLevelStatXP(string stat, uint level)
```

C++: `int GetNextLevelStatXP (IFunctionHandler * h , const char * stat , unsigned level )`

How many XP points is required for going from the level to level + 1.

docs: y · retail: confirmed (binary)

### GetPerceivedFaction

```lua
soul.GetPerceivedFaction()
```

C++: `int GetPerceivedFaction (IFunctionHandler* h )`

Returns the perceived faction (calculated from all cloths) for this soul.

docs: y · retail: unconfirmed

### GetPerceivedSuperfaction

```lua
soul.GetPerceivedSuperfaction()
```

C++: `int GetPerceivedSuperfaction (IFunctionHandler* h )`

Returns the perceived super faction (calculated from all cloths) for this soul.

docs: y · retail: unconfirmed

### GetReadCaptionObjectText

```lua
Soul.GetReadCaptionObjectText()
```

C++: `int GetReadCaptionObjectText (IFunctionHandler * h )`

docs: y · retail: confirmed (binary, vanilla×1)

### GetRelationship

```lua
soul.GetRelationship(otherSoulId)
```

C++: `int GetRelationship (IFunctionHandler * h , framework::T_WUIDScriptType other )`

returns the relationship between this and the other soul (-1 the worst enemies, 1 the best friends) Optional second argument selects the superfaction type for the other party. Can be Original, Current or Perceived.

docs: y · retail: confirmed (binary, mod×5)

### GetRoles

```lua
soul.GetRoles()
```

C++: `int GetRoles (IFunctionHandler * h )`

Returns a table=array containing role ids.

docs: y · retail: unconfirmed

### GetSchedule

```lua
soul.GetSchedule()
```

C++: `int GetSchedule (IFunctionHandler * h )`

Returns a table containing float-encoded times indexed by activities.

docs: y · retail: confirmed (binary)

### GetSkill

```lua
soul.GetSkill(string skill)
```

C++: `int GetSkill (IFunctionHandler * h , const char * skill )`

Get skill value using string name (use skill_name from database).

docs: y · retail: unconfirmed

### GetSkillLevel

```lua
soul.GetSkillLevel(string skill)
```

C++: `int GetSkillLevel (IFunctionHandler * h , const char * skill )`

Get skill value using string name (use skill_name from database).

docs: y · retail: confirmed (vanilla×7)

### GetSkillProgress

```lua
soul.GetSkillProgress(string skill)
```

C++: `int GetSkillProgress (IFunctionHandler * h , const char * skill )`

Get skill progress from the current level to the next [0,1) using string name (use skill_name from database).

docs: y · retail: confirmed (binary)

### GetSocialClass

```lua
soul.GetSocialClass()
```

C++: `int GetSocialClass (IFunctionHandler * h )`

Returns social class as a table with Id, Name and Wealth keys.

docs: y · retail: confirmed (binary, vanilla×3)

### GetSoul

```lua
Soul.GetSoul()
```

C++: `static C_Soul* GetSoul (SmartScriptTable table )`

docs: y · retail: unconfirmed

### GetSoulValue

```lua
Soul.GetSoulValue()
```

C++: `template class Enum_T> int GetSoulValue (IFunctionHandler * h , const char * const name )`

docs: y · retail: unconfirmed

### GetStat

```lua
soul.GetStat(string stat)
```

C++: `int GetStat (IFunctionHandler * h , const char * stat )`

returns stat value for a given name (str, agi, spc, vit, hea, bar, ...)

docs: y · retail: unconfirmed

### GetState

```lua
soul.GetState(string state)
```

C++: `int GetState (IFunctionHandler * h , const char * state )`

returns state value for a given name (health, stamina,...)

docs: y · retail: confirmed (binary, vanilla×8, mod×36)

### GetStatLevel

```lua
soul.GetStatLevel(string stat)
```

C++: `int GetStatLevel (IFunctionHandler * h , const char * stat )`

returns stat value for a given name (str, agi, spc, vit, hea, bar, ...)

docs: y · retail: confirmed (binary, vanilla×7)

### GetStatProgress

```lua
soul.GetStatProgress(string stat)
```

C++: `int GetStatProgress (IFunctionHandler * h , const char * stat )`

returns stat progress from the current level to the next level [0,1) for a given name (str, agi, spc, vit, hea, bar, ...)

docs: y · retail: confirmed (binary)

### GetStrength

```lua
soul.GetStrength()
```

C++: `int GetStrength (IFunctionHandler * h )`

gets the strength stat

docs: y · retail: unconfirmed

### GetSuperfaction

```lua
soul.GetSuperfaction()
```

C++: `int GetSuperfaction (IFunctionHandler* h )`

Returns the true super faction of soul. Optional second argument selects the superfaction type for the other party. Can be Original, Current or Perceived.

docs: y · retail: unconfirmed

### GetVigour

```lua
soul.GetVigour()
```

C++: `int GetVigour (IFunctionHandler * h )`

vigour 0..100

docs: y · retail: unconfirmed

### GetVitality

```lua
soul.GetVitality()
```

C++: `int GetVitality (IFunctionHandler * h )`

gets the vitality stat

docs: y · retail: unconfirmed

### HasAbility

```lua
soul.HasAbility(string ability)
```

C++: `int HasAbility (IFunctionHandler * h , const char * name )`

returns true if soul have ability (cha, ...)

docs: y · retail: confirmed (binary, vanilla×2)

### HasBuffDebug

```lua
soul.HasBuffDebug("89dada87-6e6c-5d2c-a17a-483ada14b90b")
```

C++: `int HasBuffDebug (IFunctionHandler * h , const char * buffGuid )`

supply buff definition id

docs: y · retail: unconfirmed

### HasMetaRoleByName

```lua
soul.HasMetaRoleByName()
```

C++: `int HasMetaRoleByName (IFunctionHandler* h , const char * metaroleName )`

Returns true if soul have specified role. Returns false if the soul doesn't have the specified meta role or the meta role doesn't exist.

docs: y · retail: confirmed (mod×3)

### HasPerk

```lua
soul.HasPerk("89dada87-6e6c-5d2c-a17a-483ada14b90b", true)
```

C++: `int HasPerk (IFunctionHandler * h , const char * perkDefId , bool usePerk )`

Check if soul has perk and use it.

docs: y · retail: confirmed (vanilla×4)

### HasRoleByName

```lua
soul.HasRoleByName(name)
```

C++: `int HasRoleByName (IFunctionHandler * h , char const * pRoleName )`

Returns true if soul have specified role.

docs: y · retail: unconfirmed

### HasScriptContext

```lua
Soul.HasScriptContext()
```

C++: `int HasScriptContext (IFunctionHandler * h , const char * scriptContextName )`

Checks if soul currently has script context active

docs: y · retail: confirmed (binary, vanilla×11, mod×28)

### HaveSkill

```lua
soul.HaveSkill(string skill)
```

C++: `int HaveSkill (IFunctionHandler * h , const char * skill )`

Returns true if the soul can use this level. Parameter is name from the database.

docs: y · retail: confirmed (binary, vanilla×5)

### HealBleeding

```lua
soul.HealBleeding(0.5, 1)
```

C++: `int HealBleeding (IFunctionHandler * h , float heal , int bodypartId )`

heal [0,1] bleeding on body part

docs: y · retail: confirmed (mod×1)

### IsDialogRestricted

```lua
soul.IsDialogRestricted()
```

C++: `int IsDialogRestricted (IFunctionHandler * h )`

return whether dialog is currently restricted

docs: y · retail: confirmed (binary, vanilla×2)

### IsInCombatDanger

```lua
soul.IsInCombatDanger()
```

C++: `int IsInCombatDanger (IFunctionHandler * h )`

returns 1 if the soul in in combat danger

docs: y · retail: confirmed (binary, vanilla×10, mod×17)

### IsInTenseCircumstance

```lua
soul.IsInTenseCircumstance()
```

C++: `int IsInTenseCircumstance (IFunctionHandler* h )`

returns 1 if the soul in in tense circumstance state

docs: y · retail: confirmed (binary, vanilla×4)

### IsLegalToLoot

```lua
soul.IsLegalToLoot()
```

C++: `int IsLegalToLoot (IFunctionHandler* h )`

Check whether looting the soul (dead or unconscious) will not be seen as a crime

docs: y · retail: confirmed (binary, vanilla×1)

### IsPublicEnemy

```lua
Soul.IsPublicEnemy()
```

C++: `int IsPublicEnemy (IFunctionHandler * h )`

docs: y · retail: confirmed (binary, mod×2)

### ModifyMoraleDebug

```lua
soul.ModifyMoraleDebug(5)
```

C++: `int ModifyMoraleDebug (IFunctionHandler * h , int moraleChangeId )`

debug function to modify morale, given the database change id

docs: y · retail: unconfirmed

### ModifyPlayerReputation

```lua
soul.ModifyPlayerReputation('murder', true)
```

C++: `int ModifyPlayerReputation (IFunctionHandler * h , const char * repChangeName )`

Modify NPCs relationship (reputation) to player by the given name from the database.

docs: y · retail: confirmed (binary, vanilla×1)

### OnCompanionEvent

```lua
soul.OnCompanionEvent(companion, 'EventName')
```

C++: `int OnCompanionEvent (IFunctionHandler* h , framework::T_WUIDScriptType companionWuid , const char * eventStr )`

sends an event.

docs: y · retail: unconfirmed

### OnPerkUsed

```lua
soul.OnPerkUsed("89dada87-6e6c-5d2c-a17a-483ada14b90b")
```

C++: `int OnPerkUsed (IFunctionHandler * h , const char * perkDefId )`

supply perk definition id

docs: y · retail: unconfirmed

### OverrideBodyPart

```lua
Soul.OverrideBodyPart()
```

C++: `int OverrideBodyPart (IFunctionHandler* h , const char * name , databasemodule::T_TableString S_CharacterBodyDescription::* ptr )`

docs: y · retail: unconfirmed

### OverrideCharacterElement

```lua
Soul.OverrideCharacterElement()
```

C++: `int OverrideCharacterElement (IFunctionHandler* h , const char * guidStr , entitymodule::T_CharacterElementId S_CharacterBodyDescription::* elementPtr )`

docs: y · retail: unconfirmed

### OverrideHair

```lua
soul.OverrideHair("hair_001")
```

C++: `int OverrideHair (IFunctionHandler* h , const char * hairName )`

supply hair name.

docs: y · retail: unconfirmed

### OverrideHead

```lua
soul.OverrideHead("henry")
```

C++: `int OverrideHead (IFunctionHandler* h , const char * headName )`

supply head name.

docs: y · retail: unconfirmed

### Release

```lua
Soul.Release()
```

C++: `void Release ()`

This is Release, a member of class C_ScriptBind_Soul.

docs: y · retail: unconfirmed

### RemoveAllBuffsByGuid

```lua
soul.RemoveAllBuffsByGuid(buffDatabaseId)
```

C++: `int RemoveAllBuffsByGuid (IFunctionHandler * h , const char * buffId )`

Forces removal of all buffs of the same database guid.

docs: y · retail: confirmed (binary, mod×4)

### RemoveBuff

```lua
soul.RemoveBuff(buffInstanceId)
```

C++: `int RemoveBuff (IFunctionHandler * h , framework::T_WUIDScriptType scriptWuid )`

Forces removal of a buff. Supply the buff instance id.

docs: y · retail: confirmed (binary, vanilla×2, mod×2)

### RemoveMetaRole

```lua
soul.RemoveMetaRole(id)
```

C++: `int RemoveMetaRole (IFunctionHandler * h , T_MetaRoleId id )`

Removes a metarole from this soul.

docs: y · retail: unconfirmed

### RemoveMetaRoleByName

```lua
soul.RemoveMetaRoleByName(metaroleName)
```

C++: `int RemoveMetaRoleByName (IFunctionHandler * h , char const * pMetaroleName )`

Removes a metarole from this soul.

docs: y · retail: confirmed (binary, vanilla×1, mod×1)

### RemovePerk

```lua
soul.RemovePerk(PerkInstanceId)
```

C++: `int RemovePerk (IFunctionHandler * h , const char * perk_id )`

Forces removal of a perk. Supply the perk id.

docs: y · retail: confirmed (binary, vanilla×1)

### RestrictDialog

```lua
soul.RestrictDialog(true)
```

C++: `int RestrictDialog (IFunctionHandler * h , bool bRestrict )`

set soul to dialog restricted mode so it cannot be speak to (hint will not be shown, and this functionality is implemented in lua, using IsDialogRestricted) Also deletes all unfinished requests

docs: y · retail: unconfirmed

### SetCurrStamina

```lua
soul.SetCurrStamina(float value)
```

sets CurrStamina to new value

| Param | Description |
|---|---|
| float value | value to set |

docs: y · retail: unconfirmed

### SetFood

```lua
soul.SetFood(float value)
```

sets Food to new value

| Param | Description |
|---|---|
| float value | value to set 0.0f-120.0f |

docs: y · retail: unconfirmed

### SetHealth

```lua
soul.SetHealth(ScriptHandle id, value)
```

sets health to new value

| Param | Description |
|---|---|
| float value | hp to set 0.0f-100.0f |

docs: y · retail: confirmed (mod×12)

### SetPlayerReputationDebug

```lua
soul.SetPlayerReputationDebug(-0.5, 7, true)
```

C++: `int SetPlayerReputationDebug (IFunctionHandler * h , float value , int target , bool canChangeHostility )`

debug function to directly set reputation. Use the target flags from the database.

docs: y · retail: unconfirmed

### SetSkill

```lua
soul.SetSkill(string skill, float value)
```

C++: `int SetSkill (IFunctionHandler * h , const char * skill , float value )`

Set skill value using string name (use skill_name from database).

docs: y · retail: unconfirmed

### SetSkillLevel

```lua
soul.SetSkillLevel(string skill, float level)
```

C++: `int SetSkillLevel (IFunctionHandler * h , const char * skill , T_SoulLvlValue level )`

Set skill level using string name (use skill_name from database).

docs: y · retail: unconfirmed

### SetSkillLevelDebug

```lua
soul.SetSkillLevelDebug(string skill, float level)
```

C++: `int SetSkillLevelDebug (IFunctionHandler * h , const char * skill , T_SoulLvlValue level )`

Set skill level using string name (use skill_name from database).

docs: y · retail: confirmed (vanilla×25)

### SetStat

```lua
soul.SetStat(string stat, float value)
```

C++: `int SetStat (IFunctionHandler * h , const char * stat , float value )`

sets stat value, for example soul:SetStat('str', 20), sets strength to 20

docs: y · retail: unconfirmed

### SetState

```lua
soul.SetState(string state, float value)
```

C++: `int SetState (IFunctionHandler * h , const char * state , float value )`

sets state value for a given name (health, stamina,...)

docs: y · retail: confirmed (mod×25)

### SetStatLevel

```lua
soul.SetStatLevel(string stat, float level)
```

C++: `int SetStatLevel (IFunctionHandler * h , const char * stat , T_SoulLvlValue level )`

sets stat level, for example soul:SetStatLevel('str', 20), sets strength to 20

docs: y · retail: unconfirmed

### SetStatLevelDebug

```lua
soul.SetStatLevelDebug(string stat, float level)
```

C++: `int SetStatLevelDebug (IFunctionHandler * h , const char * stat , T_SoulLvlValue level )`

sets stat level, for example soul:SetStatLevelDebug('str', 20), sets strength to 20

docs: y · retail: confirmed (vanilla×11)

### SetVigour

```lua
soul.SetVigour(float value)
```

sets Vigour to new value

| Param | Description |
|---|---|
| float value | value to set |

docs: y · retail: unconfirmed

## Verified corrections (not a real function here)

### SetTarget

> **Verified note:** `SetTarget` is not a Soul bind in the retail binary or the runtime dump. The public guide's `soul:SetTarget(nil)` cleanup call does nothing -- it is silently swallowed inside its own pcall. -- kcd2/combat-and-perception.md#the-combat-stack (verified in game)
