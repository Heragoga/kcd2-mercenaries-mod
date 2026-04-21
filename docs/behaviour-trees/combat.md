# Combat with Behaviour Trees

Excellent, we are arriving at the interesting parts. You might be reading this expecting to learn how to write a perfect AI combatant that decides when to block, when to use a combo, and when to throw out a master strike. Let me disappoint you. We modders can only issue the command to start combat to the C++ engine — it handles everything else. It even handles target acquisition after the original target dies, which means any NPC you point at an enemy becomes a ruthless viking, slaughtering every guard, man, woman and even their dog and chicken on sight.

You cannot call combat from a regular switch behaviour tree. It has to be called via the method described in [behaviour-tree-basics](behaviour-trees/basic-structure.md).

---

## Target Acquisition

Before you can start a fight, you need a target. There are a few different scenarios that apply here.

### Self-defence: reacting to being hit

The most straightforward case — your NPC gets attacked and hits back.

```xml
<ProcessMessage Atomic="true" timeout="'0ms'" timeType="GameTime" variable="$hitReaction" senderInfo="" inbox="'hitReaction'" condition="" answerVar="">
    <Sequence>
        <IfCondition failOnCondition="false" condition="$hitReaction.attacker ~= $__null &amp; $hitReaction.attacker ~= $this.id">
            <Sequence>
                <Expression expressions="$currentTarget = $hitReaction.attacker" />
                <Function_crime_getMrkev mrkev="$mrkev" nodeLabel="123" />
                <CreateInformationWrapper Label="'assault'" PerceivedWuid="$this.id" PositionType="positionWuid" PositionVec3="" PositionWuid="$hitReaction.attacker" Information="$crimeInformation" />
                <LockDynamicInformationValues Information="$crimeInformation">
                    <SetDynamicInformationValue Information="$crimeInformation" Tag="'stimulusKind'" Variable="$enum:crime_stimulusKind.combat" Type="" Value="" />
                </LockDynamicInformationValues>
                <SuppressFailure>
                    <Function_crime_limits_reserveReactionLink ffCrimeIcon="false" information="$crimeInformation" priority="160" reactionKind="$enum:crime_reactionKind.attack" nodeLabel="898989" />
                </SuppressFailure>
                <Expression expressions="
                    $attackData.target = $hitReaction.attacker
                    $attackData.information = $crimeInformation
                    $attackData.stimulusKind = $enum:crime_stimulusKind.combat
                    $attackData.previousReaction = $enum:crime_reactionKind.unknown
                    $attackData.initiatedBy = $enum:switch_interruptInitiator.switch
                    $attackData.defenceMode = false
                    $attackData.relationOverride = true
                    $attackData.source = $enum:crime_source.direct
                    $attackData.freshlyAttributedCrime = false
                    $attackData.criminalFreshness = $enum:crime_criminalFreshness.unknown
                    $attackData.escalatedFromFailedSurrender = false"
                />
                <AddInterrupt_attack attackData="$attackData" Target="$this.id" Host="$mrkev" Behavior="'YOUR_ATTACK_BEHAVIOUR_TREE'" Priority="160" IgnorePriorityOnPreviousInterrupt="true" urgency="Fast" Aliveness="Alive" Privileged="false" FastForward="false" />
            </Sequence>
        </IfCondition>
    </Sequence>
</ProcessMessage>
```

This is largely a copy-paste affair. The `IfCondition` before everything does basic sanity checks — you can add logic here to filter who counts as a valid attacker, such as excluding the player or excluding friendly fire. If you need to retrieve the actual entity from `hitReaction.attacker` to do further checks, this is the function you want:

```lua
local attacker = XGenAIModule.GetEntityByWUID(data.hitReaction.attacker)
```

`AddInterrupt_attack` is what actually kicks off combat. The `Behavior` parameter points to your attack behaviour tree — covered below. Alternatively, you can use `interrupt_attack` to call the vanilla NPC combat tree, which works out of the box but includes a lot of crime and trespass logic on top of the actual fighting. If you just want your NPC to fight and nothing else, define your own.

For `ProcessMessage` to receive hit events, the mailboxes need to be correctly defined in the subbrain. Just copy the subbrain setup from the mercenaries mod and it will work.

---

### GetTarget

A useful node for two things: detecting whether combat has already been initiated on a given NPC, and detecting who the player or surrounding NPCs are currently targeting.

```xml
<GetTarget ReferenceNPC="$candidate" TargetVarOut="$candidateTarget" />
```

`ReferenceNPC` is the NPC you're reading the target from. Use `$this.id` to check who your own NPC is currently fighting. You can also run it on the player or on NPCs surrounding your NPC — useful if they're supposed to act as guards and should engage anyone targeting the player or their allies.

---

### GetSkirmishParticipants

```xml
<SuppressFailure>
    <GetSkirmishParticipants
        ReferenceNPC="$__player"
        Active="true"
        Passive="true"
        Targets="true"
        HumanOnly="false"
        ParticipantsOutVar="$enemiesArray"
    />
</SuppressFailure>
```

This outputs an array of WUIDs currently engaged in a skirmish with the selected `ReferenceNPC`. Skirmishes are what the game calls multi-participant combat — most bandit random encounters qualify, as does attacking a bandit camp. Useful if you want your NPC to automatically join any fight the player is already in rather than waiting to be hit themselves.

---

## The Attack Behaviour Tree

Once you have a target, you need to actually start the fight. The whole thing looks like this:

```xml
<?xml version="1.0" encoding="us-ascii"?>
<BehaviorTrees>
    <BehaviorTree name="your_attack_tree" is_function="0">
        <Variables>
            <Variable name="automation_defense"  type="_bool"                          values="true"                               isPersistent="0" form="single" />
            <Variable name="automation_guard"    type="_bool"                          values="true"                               isPersistent="0" form="single" />
            <Variable name="automation_movement" type="_bool"                          values="true"                               isPersistent="0" form="single" />
            <Variable name="automation_offense"  type="_bool"                          values="true"                               isPersistent="0" form="single" />
            <Variable name="automation_weapon"   type="_bool"                          values="true"                               isPersistent="0" form="single" />
            <Variable name="weaponChange"        type="enum:weaponChange"              values="$enum:weaponChange.none"            isPersistent="0" form="single" />
            <Variable name="guardMode"           type="enum:combatAutomationGuardMode" values="$enum:combatAutomationGuardMode.automate" isPersistent="0" form="single" />
            <Variable name="isTargetAlive"       type="_bool"                          values="true"                               isPersistent="0" form="single" />
            <Variable name="distanceToPlayer"    type="_float"                         values="0.0"                                isPersistent="0" form="single" />
        </Variables>
        <Parameters>
            <Variable name="attackData" type="switch:interruptData:attack" values="" isPersistent="0" form="single" requirementType="In" />
        </Parameters>
        <Root OneTimeOnly="false" FailState="Recoverable" saveVersion="2">
            <Behavior canSkip="1">
                <EntityContext context="crime_preventDespawn" target="">
                    <EntityContextElement context="crime_interrupt" enabled="true">
                        <EntityContext context="crime_interruptAttack" target="$this.id">
                            <FuseBox StatusPropagation="Child" OneCleanup="true" saveVersion="2">
                                <Child canSkip="1">
                                    <Parallel successMode="Any" failureMode="Any">

                                        <!-- Main combat loop -->
                                        <Loop count="-1">
                                            <MoveParamsDecorator speed="Run" pathFindingParams="" doorClosingPolicy="LeaveOpened">
                                                <MeleeOffenseAutomationDecorator active="$automation_offense">
                                                    <MeleeDefenseAutomationDecorator active="$automation_defense">
                                                        <MeleeGuardAutomationDecorator GuardMode="$guardMode" active="$automation_guard">
                                                            <WeaponAutomationDecorator WeaponChange="$weaponChange" active="$automation_weapon">
                                                                <CombatFollowerDecorator ProbablisticDrivenSweetSpot="true" RPGSweetSpotArcDriver="true" active="$automation_movement">
                                                                    <Sequence>
                                                                        <Expression expressions="$isTargetAlive = false" />
                                                                        <ExecuteLua code="
                                                                            pcall(function()
                                                                                if data.attackData.target then
                                                                                    local targetEnt = XGenAIModule.GetEntityByWUID(data.attackData.target)
                                                                                    if targetEnt and yourmod:IsAliveAndWell(targetEnt, true) then
                                                                                        data.isTargetAlive = true
                                                                                    end
                                                                                end
                                                                            end)
                                                                        " />
                                                                        <IfElseCondition failOnCondition="false" condition="$isTargetAlive" saveVersion="2">
                                                                            <Then canSkip="1">
                                                                                <CombatAction TargetNPC="$attackData.target" RelationOverride="Hostile" />
                                                                            </Then>
                                                                            <Else canSkip="1">
                                                                                <Fail />
                                                                            </Else>
                                                                        </IfElseCondition>
                                                                    </Sequence>
                                                                </CombatFollowerDecorator>
                                                            </WeaponAutomationDecorator>
                                                        </MeleeGuardAutomationDecorator>
                                                    </MeleeDefenseAutomationDecorator>
                                                </MeleeOffenseAutomationDecorator>
                                            </MoveParamsDecorator>
                                        </Loop>

                                        <!-- Leash loop: fail out of combat if the NPC wanders too far from the player -->
                                        <Loop count="-1">
                                            <Sequence>
                                                <ExecuteLua code="
                                                    pcall(function()
                                                        if player then
                                                            local pp = player:GetPos()
                                                            local mp = entity:GetPos()
                                                            if pp and mp then
                                                                local dx = pp.x - mp.x
                                                                local dy = pp.y - mp.y
                                                                local dz = pp.z - mp.z
                                                                data.distanceToPlayer = math.sqrt(dx*dx + dy*dy + dz*dz)
                                                            end
                                                        end
                                                    end)
                                                " />
                                                <IfCondition failOnCondition="false" condition="$distanceToPlayer > 30.0">
                                                    <Fail />
                                                </IfCondition>
                                                <Wait duration="'2s'" timeType="GameTime" doFail="false" variation="'500ms'" />
                                            </Sequence>
                                        </Loop>

                                    </Parallel>
                                </Child>

                                <!-- Cleanup when combat ends or fails -->
                                <OnFail canSkip="1">
                                    <Sequence>
                                        <ExecuteLua code="pcall(function() entity.soul:SetTarget(nil) end); pcall(function() entity.human:DrawWeapon(false) end)" />
                                        <Wait duration="'1s'" timeType="GameTime" doFail="false" variation="" />
                                    </Sequence>
                                </OnFail>
                            </FuseBox>
                        </EntityContext>
                    </EntityContextElement>
                </EntityContext>
            </Behavior>
        </Root>
    </BehaviorTree>
</BehaviorTrees>
```

Yes, I know, this is just a lightly modified version of my mod's combat tree. It is however the simplest version of combat I've been able to get working, so here we are.

### Breaking it down

The heart of the whole thing is:

```xml
<CombatAction TargetNPC="$attackData.target" RelationOverride="Hostile" />
```

Evidently this is what starts the fight. To get it to work you need a considerable amount of wrapper nodes — all the contexts and decorators stacked around it. They are all fairly self-explanatory, and the boolean variables defined at the top of the file are how you configure the exact way your NPC fights. Set any of the `automation_*` variables to `false` to disable that aspect of the combat automation and presumably implement your own logic, though I haven't gone down that path.

**The alive check** — Before issuing `CombatAction`, the tree checks whether the target is still alive using `IsAliveAndWell` (a utility function you'll want to define in your own mod, or copy from the mercenaries mod). If the target is dead, the tree fails out. In theory. In practice, `CombatAction` has a life of its own and will happily go looking for new targets after the original one drops. This is what produces the viking behaviour mentioned at the top of this guide. I have not found a clean way to prevent it.

**The leash loop** — The second loop running in the `Parallel` is purely to stop the NPC from chasing a fleeing enemy halfway across the map. If the NPC gets more than 30 meters from the player, the loop fails, which fails the `Parallel`, which triggers `OnFail`. Tune the distance threshold to taste.

**`OnFail`** — Clears the NPC's target and sheathes their weapon when combat ends for any reason — whether the target died, the leash triggered, or something else caused the tree to fail. Without this, NPCs tend to stand there with their sword out looking angry at nothing.

The variables at the top:

| Variable | Effect |
|---|---|
| `automation_offense` | Whether the NPC automatically attacks |
| `automation_defense` | Whether the NPC automatically blocks and parries |
| `automation_guard` | Whether the NPC automatically manages their guard stance |
| `automation_movement` | Whether the NPC automatically positions itself relative to the target |
| `automation_weapon` | Whether the NPC automatically manages weapon draws and switches |
| `guardMode` | How the guard automation operates — `automate` lets the engine decide |
| `weaponChange` | Whether and how the NPC switches weapons during combat — `none` to leave it alone |
