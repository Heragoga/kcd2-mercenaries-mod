# How to Spawn an NPC

This guide covers two things: spawning an NPC at fixed coordinates on the map (standing in front of a tavern, guarding a door, etc.) and spawning one dynamically near the player (for companions, ambushes, whatever you need). The only prerequisite is a soul ID that hooks up correctly into everything defined in [xml/add-new-npc.md](../xml/add-new-npc.md).

---

## Lua Setup

If you haven't done this yet: create `data/scripts/mods/yourmodid.lua`. This is your mod's main script and gets executed on game startup.

The basic scaffold looks like this:

```lua
yourmodid = {}

function yourmodid:OnGameplayStarted(actionName, eventName, argTable)
    -- runs once when gameplay starts
    -- spawn static NPCs here
    Script.SetTimerForFunction(1000, "yourmodid.MonitorLoop")
end

function yourmodid.MonitorLoop()
    -- runs every second
    -- listen for token items, check state, react to player actions
    Script.SetTimerForFunction(1000, "yourmodid.MonitorLoop")
end

UIAction.RegisterEventSystemListener(yourmodid, "", "OnGameplayStarted", "OnGameplayStarted")
```

- `OnGameplayStarted` fires once when the level is ready. Spawn fixed-position NPCs here.
- `MonitorLoop` reschedules itself every second and runs for the lifetime of the session. This is where you listen for token items from [general/lua-skald-communication.md](../general/lua-skald-communication.md) and react to whatever the player does.

---

## Spawning an NPC at a Fixed Position

The core of everything is this call:

```lua
System.SpawnEntity({
    class      = "NPC",
    name       = entityName,
    position   = { x = x1, y = y1, z = z1 },
    orientation = safeRot,
    properties = { guidSharedSoulId = soulGuid }
})
```

- `class` — `"NPC"` for a male NPC, `"NPC_Female"` for a female one
- `name` — must be unique in the scene. A reliable naming convention is `mymod_npcname_soulid` — including the soul ID makes debugging a lot easier later
- `position` — world coordinates where the NPC will appear
- `orientation` — the NPC's facing direction. A safe value that keeps them upright is:

```lua
local playerRot = player:GetAngles()
local safeRot = { x = 0, y = 0, z = playerRot.z }
```

If you're spawning at a fixed location rather than near the player, hardcode `z` to whatever compass angle you want (`0` = north, `math.pi` = south, etc.)

- `properties.guidSharedSoulId` — the soul GUID from your soul definition. This is what ties the spawned entity to your NPC's appearance, inventory, brain, and behaviour tree.

To find a good spawn position, walk to the spot in-game and use the `cheat_loc` command from the [Cheating mod](https://www.nexusmods.com/kingdomcomedeliverance2/mods/114). It prints the current world coordinates to the console.

### Getting the Entity Back

Once spawned, retrieve the entity by name to modify it:

```lua
local ent = System.GetEntityByName(entityName)
if ent then
    -- ent.soul, ent.actor, ent.inventory, etc. are all available
end
```

---

## Spawning an NPC Near the Player

The only difference from a fixed spawn is finding safe coordinates at runtime. You can't just offset from the player position — the NPC might end up inside a wall, on a cliff edge, clipping through a market stall, or three metres in the air.

The function below handles this. It casts ten rays in a 100° arc behind the player, picks the direction with the most clear space, clamps the spawn distance away from any geometry, and then ground-snaps the final position with a downward raycast.

```lua
function yourmodid:GetSafeSpawnPosition(pe, distance)
    if not pe then return nil, nil end
    distance = distance or 3

    local playerPos = pe:GetWorldPos()
    local playerDir = pe:GetDirectionVector()
    local playerRot = pe:GetAngles()

    -- Guard: zero direction vector means we're in a cutscene or transition
    if not playerDir or (playerDir.x == 0 and playerDir.y == 0) then
        return nil, nil
    end

    local eyePos     = { x = playerPos.x, y = playerPos.y, z = playerPos.z + 1.6 }
    local rayDistance = distance + 2
    local hitTable   = {}
    local numRays    = 10
    local arcAngle   = 100
    local startAngle = -arcAngle / 2
    local angleStep  = arcAngle / (numRays - 1)
    local bestDir    = nil
    local bestDist   = -1
    local backDir    = { x = -playerDir.x, y = -playerDir.y, z = -playerDir.z }

    for i = 0, numRays - 1 do
        local angleOffset = startAngle + (i * angleStep)
        local rotatedDir  = VectorUtils.Rotate2D(backDir, angleOffset)

        if rotatedDir then
            local checkVec = VectorUtils.Scale(rotatedDir, rayDistance)
            -- ent_terrain + ent_static: ignore dynamic entities (NPCs, horses, etc.)
            local hits = Physics.RayWorldIntersection(
                eyePos, checkVec, 2, ent_terrain + ent_static, pe.id, nil, hitTable
            )

            local clearDist = rayDistance
            if hits > 0 and hitTable[1] and hitTable[1].dist then
                clearDist = hitTable[1].dist
            end

            -- Bias toward directly behind the player rather than the sides
            local anglePenalty = (math.abs(angleOffset) / arcAngle) * 0.5
            local score = clearDist * (1.0 - anglePenalty)

            if score > bestDist then
                bestDist = score
                bestDir  = rotatedDir
            end
        end
    end

    if not bestDir then return nil, nil end

    -- Stay 0.5m clear of the nearest hit, don't exceed requested distance
    local spawnDist
    if bestDist < rayDistance then
        spawnDist = math.max(math.min(bestDist - 0.5, distance), 0.8)
    else
        spawnDist = distance
    end

    local spawnPos = {
        x = playerPos.x + bestDir.x * spawnDist,
        y = playerPos.y + bestDir.y * spawnDist,
        z = playerPos.z,
    }

    -- Ground snap: start 5m up to avoid interior ceiling hits
    local groundHitTable  = {}
    local groundCheckStart = { x = spawnPos.x, y = spawnPos.y, z = spawnPos.z + 5.0 }
    local groundCheckDir   = { x = 0, y = 0, z = -100 }
    local groundHits = Physics.RayWorldIntersection(
        groundCheckStart, groundCheckDir, 2, ent_terrain + ent_static, 0, nil, groundHitTable
    )

    if groundHits > 0 and groundHitTable[1] and groundHitTable[1].pos then
        spawnPos.z = groundHitTable[1].pos.z
    else
        spawnPos.z = playerPos.z  -- fallback: use player Z if ground snap fails
    end

    return spawnPos, playerRot
end
```

### Using It

```lua
local spawnPos, playerRot = yourmodid:GetSafeSpawnPosition(player, 3)

if spawnPos then
    System.SpawnEntity({
        class       = "NPC",
        name        = "mymod_merc_" .. math.random(99999),
        position    = spawnPos,
        orientation = { x = 0, y = 0, z = playerRot.z },
        properties  = { guidSharedSoulId = "your-soul-guid-here" }
    })
end
```

Always check that `spawnPos` is not `nil` before spawning. The function returns `nil, nil` if it can't find a safe spot — this happens during cutscenes, fast travel transitions, or if the player is somewhere the raycast can't resolve (underground, interiors with odd geometry, etc.).

### Spawning in Front of the Player

The function spawns behind the player by default. To spawn in front, invert `backDir` before the ray loop:

```lua
local backDir = { x = playerDir.x, y = playerDir.y, z = playerDir.z }
```

---

## Notes

- **`guidSharedSoulId` vs `sharedSoulGuid`** — these look interchangeable but they are not. The property key inside `System.SpawnEntity` is `guidSharedSoulId`. Using the wrong one produces an NPC with no soul, no inventory, no brain, and no visible errors.
- **Entity name collisions** — if an entity with the same name already exists in the scene, `System.SpawnEntity` will silently fail or overwrite it depending on engine version. Always generate a unique name, or check `System.GetEntityByName(name) == nil` before spawning.
- **NPC vs NPC_Female** — the `class` field must match the `soul_archetype_id` in your soul definition (`0` = male = `"NPC"`, `1` = female = `"NPC_Female"`). Mismatching them produces a T-posed mess.
