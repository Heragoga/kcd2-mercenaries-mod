# Movement with Behaviour Trees

If you haven't read [basic-structure](behaviour-trees/basic-structure.md) I highly recommend you do so now, as this guide only presents a few nodes and the surrounding details that enable movement.

---

## A Word on How NPC Movement Works

First of all: movement of NPCs in KCD2 is a fairly complex thing. I am fairly certain that every behaviour tree on a given level is executed all the time — even if the NPC model isn't rendered. Example: in many quests, when a quest giver migrates (actual in-game terminology), their icon moves on the map, implying the game calculates their movement even if they are hundreds of meters away from the player. I've noticed the same with the mercenaries mod — even if they're standing on the other side of the map, they continue to log things, and if you recall them via innkeeper their behaviour tree will teleport them to the player.

I wouldn't put too much trust in this observation however, as KCD2 is an incredibly well optimised game, and no sane programmer executes hundreds of behaviour trees simultaneously when the player can't see any of them. There's probably some LOD system at work that I'm not aware of.

---

## The Move Node

This is one of the ways you can make an NPC move. It is strictly: move to entity X. I recommend only using it if your NPC should walk somewhere alone, because if multiple NPCs are pathing through a small space simultaneously — say, you spawn a few soldiers in a line and tell them all to walk to Kuttenberg marketplace at the same time — they will see each other as obstacles and try to avoid each other, which means they start scattering in increasingly weird ways. For a demonstration of what that looks like, dig up the 1.0 version of the mercenaries mod. I used this approach back then and it was not pretty.

```xml
<Move
    stopWithinDistance="5.0"
    stopDistanceVariation="2.5"
    rayCasteFlee="false"
    successDistance="0.0"
    changeNPCState="false"
    fastForwardIncludesMove="false"
    destinationSpecification="$__player"
    destinationSpecification2="$distanceToFlee"
    destinationSpecification3="$keepMinimalDistance"
    speed="Sprint"
    additionalParams="$MoveParams_fleeing"
    pathFindingParams="$pathParams_fleeing"
    staminaPolicy=""
    pathInfo=""
/>
```

### Parameter reference

**`destinationSpecification`** — The most interesting part. This is a WUID pointing to a specific entity on the map — not XYZ coordinates, but an actual entity like an NPC, a chair, or a dummy entity you spawned yourself. If the entity moves, the pathfinding will adjust and the NPC will keep walking toward its new position.

**`destinationSpecification2`** — The distance from the goal the NPC should stop at. Leave empty if you want the NPC to walk all the way to the goal.

**`destinationSpecification3`** — The minimum distance the NPC should always maintain from the goal. Leave empty if you don't need it.

**`speed`** — Self-explanatory. `Walk`, `Run`, `Sprint` etc.

**`stopWithinDistance`** — The radius around the target where the NPC will consider the movement done.

**`stopDistanceVariation`** — Adds variation to the stop radius so multiple NPCs don't all stop at exactly the same point. Useful if you don't want a perfectly symmetrical ring of soldiers around a destination.

**`successDistance`** — How close the NPC needs to be to the goal for the Move node to exit successfully.

**`changeNPCState`** — Very important. If this is set to `true` and your behaviour tree is a switch, it will crash. Always set it to `false`.

**`fastForwardIncludesMove`** — Decides whether this node executes when the player fast forwards time.

**`additionalParams`** and **`pathFindingParams`** — More configuration. Here are the relevant variable definitions:

```xml
<Variable name="MoveParams_follow"  type="additionalMoveParams" values="destChangedThreshold('100ms')" isPersistent="0" form="single" />
<Variable name="pathParams_follow"  type="pathFindingParams"    values="usePaths(true),useGeneratedNSO(true),useSmartObjects(true)" isPersistent="0" form="single" />
<Variable name="MoveParams_fleeing" type="additionalMoveParams" values="destChangedThreshold('1s')"    isPersistent="0" form="single" />
<Variable name="pathParams_fleeing" type="pathFindingParams"    values="usePaths(true),useGeneratedNSO(true),useSmartObjects(true)" isPersistent="0" form="single" />
```

`additionalMoveParams` dictates how frequently the target entity's position is polled. `pathFindingParams` defines how the NPC finds its path:

- **`usePaths`** — Whether to use vanilla roads and streets, the same paths a horse can follow
- **`useSmartObjects`** — Whether to use doors, ladders, and similar interactables
- **`useGeneratedNSO`** — Honestly no idea. It's in every example I've seen so I leave it in

For `staminaPolicy` and `pathInfo`, your best bet is to search for references to the Move node in the base game files and see how they're used there.

---

## The ExactMove Node

If you need more precise positional control, `ExactMove` moves the NPC toward a destination with finer configuration options. Most parameters are the same as the regular Move node.

```xml
<ExactMove
    directionType="AlignWithEntity"
    directionSpecification="$moveSpot"
    animationTriggerDist="0.150000"
    precise="true"
    changeNPCState="false"
    fastForwardIncludesMove="false"
    destinationSpecification="$moveSpot"
    destinationSpecification2=""
    destinationSpecification3=""
    speed="Run"
    additionalParams=""
    pathFindingParams=""
    staminaPolicy=""
    pathInfo=""
/>
```

**`directionType`** — Controls how the NPC orients itself during movement. `AlignWithEntity` makes them face the destination entity.

**`precise`** — Whether the NPC tries to hit the exact destination position rather than stopping within a radius.

---

## The CrimeFollower Node

This is the one to use when you want multiple NPCs to follow a specific entity and actually look good doing it. The regular Move node technically handles following, but as discussed above, when multiple NPCs use it to follow the same target they get in each other's way and scatter. `CrimeFollower` does not have this problem.

It maintains a set distance from the target automatically, adjusts speed to catch up when falling behind, and handles multiple NPCs following the same entity without them turning into a panicked mob.

```xml
<CrimeFollower
    Target="$followTarget"
    Mode="Default"
    Role="Main"
    RelativeSpeedLimit="Dash"
    DisableGhosting="false"
    BlockWay="false"
/>
```

**`Target`** — A WUID pointing to the entity to follow.

**`Mode`** — Controls the following behaviour. `Default` makes the NPC walk to and maintain distance from the target. There are other modes for things like just looking at an entity without moving — search the vanilla files for the exact options.

**`Role`** — Controls the follow distance. `Main` keeps the NPC fairly close. `Assist` gives a bit more space. Useful if you have a mix of NPCs that should form up at different distances.

**`RelativeSpeedLimit`** — The maximum speed the NPC will use to catch up. `Dash` means they will sprint if they fall far enough behind.

**`DisableGhosting`** — Ghosting is what happens when you walk into an NPC for long enough and they become passthrough so you can move through them. Setting this to `false` leaves that behaviour enabled.

**`BlockWay`** — Whether the NPC physically blocks passage. In tight spaces this doesn't work perfectly regardless of how it's set.

---

## Moving to Specific XYZ Coordinates

This is the tricky part. I have no doubt there is a very clean native way to do this somewhere in the game, but if so, I haven't found it. The best workaround I can offer is spawning a dummy entity at the target coordinates and using that as the movement destination.

### Step 1: Spawn the target entity

```lua
-- Use a unique name tied to the NPC so you can clean it up later
-- Naming the NPC with a random number and embedding it in the
-- target entity's name is a clean way to handle this
local targetName = "mytarget_destination_" .. tostring(npcRandomId)
local searchPrefix = "mytarget_destination_" .. tostring(npcRandomId)

-- Clean up any existing entity with this name first
local allEntities = System.GetEntitiesByClass("BasicEntity")
if allEntities then
    for i, ent in ipairs(allEntities) do
        local name = ent:GetName()
        if name and string.sub(name, 1, string.len(searchPrefix)) == searchPrefix then
            System.RemoveEntity(ent.id)
        end
    end
end

-- Spawn the new target entity at the desired coordinates
System.SpawnEntity({
    class    = "BasicEntity",
    name     = targetName,
    position = {x = x1, y = y1, z = z1}
})

-- Retrieve the entity reference
local targetEnt = System.GetEntityByName(targetName)
-- targetEnt.id or targetEnt.this.id is your movement target
```

### Step 2: Pass the entity into the Move node

Pass `targetEnt.id` (or its WUID) into `destinationSpecification` on your Move node and the NPC will path to those coordinates as if it were any other entity.

### Important

Always despawn the target entity when the behaviour tree branch is done with it. Leaving dozens of invisible `BasicEntity` objects scattered across the map is a great way to make your future self very confused. The unique naming scheme mentioned in the comment above makes cleanup trivial — just search by prefix and remove anything that matches.
