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
            -- NOTE: parameter 5 must be the entity pointer (pe), not pe.id.
            -- Passing pe.id causes a "Wrong parameter type: expected Pointer, got Number"
            -- warning and silently disables the exclusion, meaning the raycast may
            -- hit the player's own collision and return a bogus near distance.
            local hits = Physics.RayWorldIntersection(
                eyePos, checkVec, 2, ent_terrain + ent_static, pe, nil, hitTable
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

## Spawning while the player is indoors

`GetSafeSpawnPosition` is an **outdoor** helper and behaves badly inside a building. Two separate
problems, both of which were live in the innkeeper hire path:

1. **It never leaves the room.** It only probes ~5 m behind the player (`rayDistance = distance + 2`),
   so in any room larger than that it just finds clear floor a few metres away — which is why men hired
   from an innkeeper mustered in his taproom instead of the street.
2. **Its ground snap can land them on the roof.** The snap starts `spawnPos.z + 5.0` and casts *down*.
   Inside a building 5 m up is usually above the ceiling, so the first solid surface the ray meets is
   the **roof**, and `spawnPos.z` comes back as the roof height. `FindValidGround` then inherits that
   polluted `refZ`, so `CampValidateSpot` measures the rooftop against itself, finds no rise, and
   validates it. The NPC really does spawn — over the player's head. From the player's chair that is
   indistinguishable from "they didn't spawn at all".

The cure is not to widen the rays (a tavern common room can exceed any sane ray budget). Decide
*before* placement whether the player is indoors, and relocate the whole muster point. Every hire path
goes through one helper:

```lua
local a = mercenaries:HireSpawnAnchor()          -- { pos, rot, outside, snap }
local offsetPos = a.snap and mercenaries:FindValidGround(raw, a.pos.z) or raw
```

It resolves three cases:

| Case | `pos` | `snap` |
|---|---|---|
| Player outdoors | `GetSafeSpawnPosition` as before | `true` |
| Indoors, open ground within reach | the outdoor anchor | `true` |
| Indoors, nothing open within reach (mine, keep, cellar) | in-room x/y, **the player's own z** | `false` |

That third row is the one that is easy to get wrong. `snap = false` means "place them exactly here, do
not ground-snap and do not validate" — because *both* `CampSnapToGround` and `CampValidateSpot` probe
from above, so in an enclosed interior they find the roof, not the floor. The player's own z is the one
height you know for certain is a real floor.

`FindOutdoorSpawnAnchor` (`mercenaries_util.lua`) returns `pos, underRoof`: `nil, false` when the
player is already outdoors, `pos, true` when it found open ground, `nil, true` when he is indoors with
nowhere to go. Indoors it walks rings of bearings outward from `OutdoorAnchorMin` to `OutdoorAnchorMax`
and keeps the first candidate that has open sky over it (`CampDetectRoof`) *and* ground a man can stand
on (`CampValidateSpot`). Rejecting an indoor candidate costs **one** ray, so the inside-the-building
half of the search is nearly free; only open-sky candidates pay the nine-ray footprint check, and those
are capped by `OutdoorAnchorTries`.

Two details that matter:

- **The two probes use different reference heights, deliberately.** The *standability* check is
  candidate-relative — hired upstairs the street is several metres below, and judging it against the
  floor he is standing on rejects the whole street. The *roof* probe is player-relative, because the
  question it answers is "is there still something over my head at this bearing", i.e. have we left the
  building. That costs a slope bias: open ground more than `CampRoofDetectHeight` (3 m) **above** his
  feet reads as roofed and is skipped. Err that way on purpose — it only drops some of the 16 bearings
  per ring, whereas the tempting "fix" (snap first, then probe from the snapped height) is actively
  wrong, because a snap taken indoors lands on the roof and would make a rooftop candidate look like
  open sky. That is the bug the whole function exists to avoid.
- **Half-step alternate rings** so samples never line up in spokes and re-probe the same wall all the
  way out.
- **Tell the player.** They are out of sight by design, so a hire indoors reads as nothing having
  happened unless something says so (`merc_info_hired_outside`).

Related: `CampDetectRoof` is the mod's only notion of "indoors" — a single downward ray from 50 m up,
true when the first hit is `CampRoofDetectHeight`+ above the player's feet. A tree canopy passes
through it, so open woodland is not a false positive. There is no engine `IsPointIndoors`.

### Count what actually spawned

`System.SpawnEntity` can succeed as a call and still leave `System.GetEntityByName` returning `nil`
(position embedded in geometry, for one). A hire loop that only does `if ent then ... end` charges the
player, bumps the count, and prints "hired" for men who never existed. Count the entities that came
back, refund the difference, `Recount()`, and only claim success for what really arrived.

---

## Notes

- **`guidSharedSoulId` vs `sharedSoulGuid`** — these look interchangeable but they are not. The property key inside `System.SpawnEntity` is `guidSharedSoulId`. Using the wrong one produces an NPC with no soul, no inventory, no brain, and no visible errors.
- **Entity name collisions** — if an entity with the same name already exists in the scene, `System.SpawnEntity` will silently fail or overwrite it depending on engine version. Always generate a unique name, or check `System.GetEntityByName(name) == nil` before spawning.
- **NPC vs NPC_Female** — the `class` field must match the `soul_archetype_id` in your soul definition (`0` = male = `"NPC"`, `1` = female = `"NPC_Female"`). Mismatching them produces a T-posed mess. The `class` determines which base skeleton is committed at spawn time — the soul applies appearance on top but cannot change the skeleton after the fact. Even passing a known female soul GUID will not fix a male skeleton if the class is wrong.
