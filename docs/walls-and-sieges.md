# Walls, pathfinding and staged battles

Three systems, in the order a fight uses them.

| File | Job |
| --- | --- |
| `mercenaries_wall.lua` | building the palisade (barrel markers -> tiled wall segments) |
| `mercenaries_navmesh.lua` | a custom grid + A* so mod NPCs route around the wall, and the local layer that rounds tents |
| `mercenaries_wallbattle.lua` | staging a fight at the gaps before combat opens |
| `mercenaries_raids.lua` | deciding when a raid happens, how big it is and who turns up |

## Building the wall

Left-click marks a corner, right-click finishes. Two rules the player runs into:

- a corner must be far enough from the last one to fit a whole segment
- a corner may come no closer than `WallGateMin` (5 m) to **where the run began**, so the
  ring can never be sealed. A camp with no way in has no gap for the staged battle to
  muster at, and the fight degenerates into everyone clipping through the palisade

### Gate sentries

The first two camp guards are posted at the camp's **gates** once any exist; with none they
fall back to the two ends of the longest wall stretch. Everyone else keeps patrolling the
perimeter.

> The old "a corner may not be marked within `WallGateMin` of the start" rule no longer
> forces the gateway — `WallGateMin` is 0 and gate snapping does the job instead. See
> [gates.md](gates.md).

A post is just a patrol route with a single waypoint: `camp_actor` walks there,
`AdvancePatrolWaypoint` leaves the index where it is, and the man stands. No behaviour-tree
work was needed for a guard who holds a position rather than walking a loop. Posts sit
`NavGateInset` inside the wall line so a sentry is not standing in the palisade mesh.

Routes are re-cut by `NavRefreshPatrolRings` (from `EndWallBuild`, from `DefRestore`, or by
hand with `merc_nav_patrol`). Sentries are ordinary defenders when a raid comes: the staged
battle pulls them to the muster line like anyone else.

Starting a new wall while one stands takes the old one down first — marking onto an
existing run would join the two into one impossible polygon. Removing all upgrades at the
quartermaster clears the wall too (`LogiRemoveAllUpgrades` → `DefClearWorld` → `WallClearAll`),
along with the towers and carts, and forgets them so the camp rebuild does not put them back.

## Picking a wall mesh (`merc_wall_matrix`)

`WallTypes` is a hand-picked list; `merc_wall_matrix` is the gallery it gets picked from.
204 base-game stone walls, towers and gates in seven groups, laid out as bands running
away from you:

| Group | N | What it is |
| --- | --- | --- |
| `kit` | 29 | `walltool` Kutna Hora city wall: tall, tileable, with straights, 90 degree corners, ends and gates. The only stone set built to be repeated, so the one a builder wants |
| `low` | 48 | `walltool` low stone walls: property and garden height, capped with shingles or plaster |
| `seg` | 13 | loose stone segments (`wall_segment_220_60_a_*`) and low ruined pieces |
| `ruin` | 28 | ruined fortress wall pieces (Cimburk and generic) |
| `castle` | 38 | castle-scale runs: Malesov, Suchdol, Trosky lower castle, `castle_wall_test`. Whole level walls, tens of metres each |
| `tower` | 18 | towers and bastions to anchor the corners |
| `gate` | 30 | stone gates and gatehouses |

`merc_wall_matrix` with no argument prints that menu. Each group carries its own cell
size, because a 2 m kit piece and a 60 m fortress wall cannot share one spacing. `all`
spawns every group in its own band and runs about a kilometre deep, so one group at a
time is easier to read.

- `merc_wall_mx_where` names the piece you are standing at and prints a `WallTypes` row
  ready to paste
- `merc_wall_mx_use` points a scratch wall type at it, so `merc_wall_build` draws with it
  straight away and `merc_wall_len` / `merc_wall_up` / `merc_wall_yaw` can fit it
- `merc_wall_mx_yaw`, `merc_wall_mx_up`, `merc_wall_mx_list`, `merc_wall_matrix_clear`

Two things to settle on a candidate before it ships as a wall type:

- **collision.** A mesh with a sibling `cv_*.cgf` in the pak carries no collision of its
  own: it renders and the player walks through it. Those are marked `-- cv` in
  `WallMxGroups` and need the invisible-crate treatment the gate colliders use.
- **pivot.** Kit pieces stand on their own base; the level-scale ones are placed by the
  level at a baked height, so expect `merc_wall_up` to end up several metres negative
  (the palisade already sits at -3.00).

## Why a custom navmesh

The wall is spawned at runtime, so the engine navmesh knows nothing about it. Everything
that would normally stop an NPC walking through was tried and ruled out:

- `AI.SetPFBlockerRadius`, `AI.CreateTempGenericShapeBox` — no effect on spawned walls
- all 24 `g_PhysicsCollisionClass` classes — none block AI pathing
- the `sa_deterrentArea` prefab — the area instantiates but its `TagPoint` will not spawn,
  and it is gated on `global_deterrentAreasActive`
- NPC-vs-NPC body blocking — NPCs push through each other

### What the binary says, though

That list is what was *tried*, and every entry failed. It is not evidence that the engine
cannot do it, and a strings dump of `WHGame.dll` says fairly clearly that it can. Reasons
each of the above was the wrong tool:

- `AI.SetPFBlockerRadius(entityId, blocker, radius)` acts on an entity's **AI object**.
  A `mercenaries_Prop` has none, so the bind had nothing to act on — it did not disprove
  the mechanism, it never reached it.
- `AI.CreateTempGenericShapeBox` makes an *AI anchor-typed generic shape*, a query volume.
  It was never a pathfinding primitive.
- collision classes are physics, and the navmesh is not physics.

What is actually in the binary:

| Name | The engine's own help text |
| --- | --- |
| `wh_ai_ObstaclesAddToCollisionAvoidance` | "Add **static obstacles** to the collision avoidance. 0 - no, 1 - yes, 2 - yes but exclude obstacles with ignore radius" |
| `wh_ai_FindPathUseObstacles` | "Include obstacles when computing costs within the nav mesh search" |
| `wh_ai_FindPathObstaclesMultiplier` | "Distance multiplier that is added as extra cost to the part of paths within obstacles" |
| `wh_ai_AutomaticMNMRebuild` | "Enables automatic rebuilding of nav mesh when **a change in level is detected**" |
| `ai_MovementSystemPathReplanningEnabled` | re-plans a moving actor "every time a **navigation-mesh change at runtime** affects their current path" |
| `ai_AdjustPathsAroundDynamicObstacles` | "Set to 1/0 to enable/disable AI path adjustment around **dynamic obstacles**" |
| `ai_DebugDrawNavigationWorldMonitor` | "Enables displaying **bounding boxes for world changes**" |

So: runtime navmesh change is a first-class feature of this build, there is a world
monitor watching for it, there is a static-obstacle channel into collision avoidance, and
`C_NavMeshTileRuntimeAdjustmentTask` and `C_NavMeshGeneratorUpdateThread` are real classes
in `wh::xgenaimodule::navigation`. `wh_ai_OverrideMNM` ("Recast navmesh and detour
pathfinding are used in the movement") says movement runs on **Recast/Detour with a tile
cache**, and a Detour tile cache is precisely the structure that supports adding obstacles
at runtime.

Two claims that turned out to be false, so nobody chases them again:

- **`AIRadius` and `NotTriangulate`** appear in every shipping `.cgf.dfp` sidecar, and
  neither string exists anywhere in `WHGame.dll`. They are legacy CryEngine brush fields
  the resource compiler still writes and the game never reads.
- **`$move`** does not exist in `WHGame.dll` or in `rc.exe` — 0 occurrences, any case. The
  real CGF node conventions, from `ResourceCompilerPC.dll`, are `$physics_proxy`,
  `$collision` and `$lod`.

One claim that turned out to be exactly right: **NPC collision is not player collision.**
The `.cgf.dfp` `<CollisionFiltering>` block carries 23 separate classes, among them
`gcc_player_capsule` and `gcc_player_body` on one side and `gcc_ai`,
`gcc_npc_reported_type`, `gcc_npc_ignored_type` and `gcc_npc_avoiding_types` on the other.
A mesh can be solid to the player and transparent to an NPC by authoring alone — and since
the mod can now compile its own `.cgf` (see [custom-assets.md](custom-assets.md)), it can
ship a wall with its own sidecar.

Two ways of giving a wall segment an AI object, so `SetPFBlockerRadius` has something to
act on, are already ruled out: `sWH_AI_EntityCategory` is a **smart-object** category
(its shipping values are `Seat`, `Bed`, `Chest`, `well`, `diceTable`...) and does not
create one, and `pathRadius` is the **agent's own** footprint - it appears only on
`Scripts/Entities/AI/*` walkers (NPC 0.25, animals and horses 0.4), never on a prop. So
the obstacle channel is most likely fed by mesh authoring and by the world monitor, not by
a Lua call on a spawned prop. `C_AIObstacles` / `I_AIObstacles` is a real subsystem; what
registers into it from data is still unknown.

`merc_nav_engine`, `merc_nav_engine_arm` and `merc_nav_blockers` exist to test all of this
from the console. Nothing in the mod arms any of these cvars on its own.

`tools/navlab.ps1` runs the whole thing closed-loop: launch, Continue, F11, wait for the
report, kill. The lab finds its own lane from wherever the save leaves the player
(`LabFindLane`: the clearest of 24 bearings, ground found under it for 50 m with no step
over `LabLaneMaxRise`), and refuses with "no clear lane" rather than measuring against a
building.

### What the lab measured

`merc_wall_lab` was run six times closed-loop (`tools/navlab.ps1`: launch, Continue, numpad-9,
locate a lane, run, quit). The first five runs were harness bugs, each worth knowing:

- the test NPC spawned at the **player's** position, so every "avoidance" lateral in the
  first two hand runs (7.60 m, 9.45 m, 7.50 m) was the player standing off the axis - the
  9.45 m "AROUND" was the player walking to the end of the wall to look at it;
- `ChainDef("LabLocate", ...)` made `self.LabLocate` a function from load and the
  start guard refused every run (chain base names are live fields - see the timer docs);
- `mercenaries_cmdui.lua` binds F11 whenever it is on, so the harness key is numpad-9;
- with the company following the player, the squad killed the walker on his spawn
  point twenty trials running (`TryClaimTarget` now withholds him while a lab runs);
- a 48 m lane with two 21 m flanks exists nowhere on the map; the finder now asks for
  ground under the wall's own 16 m line and 8 m beyond it.

**The sixth, and the one that has cost the most: the walk order silently not taking.**
`testnpc_scheduler.xml` hands the walk over with
`Function_crime_getMrkev` inside a `SuppressFailure`, then `AddInterrupt` with that
carrot as `Host`. When the carrot fails, the interrupt is added with an empty host,
`testnpc_walk` never runs, **and the `[TestNpc] walk interrupt fired` line still prints**
- so the log looks exactly like a healthy trial while the man stands on his spawn point
at `speed=0 anim=MotionIdle`. Two whole runs were voided by it and the previous
investigation wrote it off as "nondeterministic". It is sticky: once a session is failing
it stays failing, and re-raising the request ten times changes nothing.

`LabKickIfStalled` now re-orders a walker who has not covered 0.5 m after
`LabKickAfter` (4 s), logs his speed and animation state, and counts the re-orders into
the trial so a rescued trial is never read as a clean one. It does not *fix* the
hand-off. **Before trusting any lab run, check the log for `WALKER NEVER MOVED`** - and
prefer measuring on the company (`merc_solid_selftest`), who follow the player with no
interrupt in the way, over anything that depends on this rig.

Run six was clean - the walker starts on the axis (lateral 0.00) and walks - and every
one of ten cases, two trials each, went **THROUGH**, passing 2-40 cm from the timber line:

| the wall was | mean lateral |
| --- | --- |
| the palisade as the mod spawns it | 0.04 m |
| 60 thick invisible box colliders (the player-house trick) | 1.11 m |
| the palisade as **five-tonne rigid bodies** | 0.00 m |
| the palisade under `gcc_ai`, `gcc_npc_reported_type`, `gcc_player_type` | 0.00-0.45 m |
| any of those plus `wh_ai_ObstaclesAddToCollisionAvoidance = 1` | 0.00-0.36 m |

So NPC locomotion does not resolve against anything spawned at runtime: not static
geometry, not a rigid body it is known to shove when it walks into one, not any collision
class, not the avoidance cvars.

For a while that was written up here as a property of the engine and the end of the road.
It is not. **It is one cvar, and it is off by default.** See below.

### It was never the navmesh: `ac_disableLivingVsRigidCollisions`

The lab set above never checked the one thing every result rested on - that the wall was
physically there at all. `merc_wall_lab_solid` fires a ray across the built wall at ankle,
hip and chest height before each trial, and it hits `MercWallSeg_*` at every height, every
trial. The palisade mesh carries a real `$physics_proxy` node
(`$physics_proxy_proxy_palisade_wall_aaaa_013`), `mercenaries_Prop` physicalises it
PE_STATIC, and the player is stopped by it. So the wall is solid and the NPC is not
stopped by it, which is a statement about the NPC, not about the wall.

The engine keeps a separate collision setup for AI and for the player, and says so:

> `ac_disableLivingVsRigidCollisions` - "Disable collisions between living and rigid
> entities. **Must reload level (or update collider mode otherwise) to work.**"

KCD2 ships that ON. An NPC's living entity is built with rigid and static entities
filtered out of the set it resolves against; the player's is not. That is the whole of
"NPC collision is not player collision", and no amount of navmesh work would ever have
reached it.

`merc_wall_lab_solid` ran eleven other candidates first, two trials each, and the table is
worth keeping because of how uniformly they fail:

| case | blocked | mean lateral |
| --- | --- | --- |
| control | 0/2 | 2.88 m |
| `ac_ColliderModeAI` = 2 GroundedOnly / 3 Pushable / 4 NonPushable | 0/2 | 2.85-2.91 m |
| `SetColliderMode(3)` / `(4)` on the walker himself | 0/2 | 2.91-2.96 m |
| `SetColliderMode(4)` on all six wall pieces | 0/2 | 2.94 m |
| `ac_movementControlMethodHor = 1` (Entity MCM), alone and with mode 4 | 0/2 | 2.82-2.83 m |
| `ac_enableExtraSolidCollider = 1` | 0/2 | 2.98 m |
| **`ac_disableLivingVsRigidCollisions = 0`** | **2/2** | **5.50 m** |
| no wall built, override on (the other-way control) | 0/2 | 2.90 m |

The control's lateral is what a straight line looks like, and every failing case sits on
it. The one that works stops him dead - "never passed the wall plane, walked 12.7 m, wall
at 13.0 m", both trials - and its 5.50 m lateral is him **sliding along the timber**,
which is what a wall is supposed to do.

All 23 cvars the lab touches report `registered` in the retail build, so none of this is
editor-only.

### Shipping it: [mercenaries_solid.lua](../data/Scripts/mods/mercenaries_solid.lua)

Confirmed in play: with this on, **nothing walked through a wall.**

**Which way round it is scoped, and why.** Two facts pull in opposite directions, and
getting this backwards is what made the first shipped version unreliable.

The flag is read when a character is **physicalised**. So leaving it armed is *reliable* -
everything that streams in or spawns is born solid and there is nothing to miss. That is
the version confirmed in play.

A collider-mode change also re-applies it, to one man, leaving everyone else alone. So the
flag can be *scoped* per man - but only as reliably as our own bookkeeping. The first
attempt scoped it that way round, arming the cvar for one pulse at a time and never leaving
it armed, and it missed men constantly: **a running man covers more ground between ticks
than the band is wide**, and anything spawning between two ticks is born permeable.

So it is done the way round that fails safe. While the player is within `SolidGate` (140 m)
of a wall of ours the flag is **armed and left armed** - the half that cannot miss anybody -
and the per-man pulse is used only to **hand back** men who are not within `SolidWallNear`
(20 m) of a wall. Steady state is what was wanted, only men near a wall are solid, and the
failure mode is a man solid for one tick longer than he needed to be rather than not solid
when it mattered. Away from every wall the cvar goes back to its shipping value and
everyone is handed back, so the rest of the world is untouched.

Everyone within `SolidRegion` (150 m) of the player is bookkept, not just men near the
wall: while the flag is armed *any* of them may have been born solid, and a man who is not
bookkept is a man nobody ever hands back.

The pulse must be a real **change** - re-requesting the mode a man is already in can be
dropped - so it steps through 3 (Pushable) and back to 0 (Undefined, the engine's own
choice). The shipping door smart object does the same with 7 and 0, and the lab measured
both 3 and 0 as inert on their own.

The tick is `SolidTickMs` (1 s) while armed and `SolidIdleMs` (4 s) when there is nothing
to do. One second is chosen against the band: a sprinting man covers about 6 m of a 20 m
band per tick.

`merc_solid 2` is the blunt version - everyone near the company, wall or no wall.
`merc_solid 0` never touches anything. `merc_solid_status` prints the armed state, how many
men are bookkept, solid, handed back and awaiting a reroute.

### The other half: a man leaning on the timber

Making a man solid tells the pathfinder nothing. The navmesh is still baked, so he still
*aims* through the palisade — the difference is that now his body stops him. Where the
mod's own steering covers him he goes round; where it does not — in combat, outside
`NavActiveRadius`, during a `NavFollowCooldown` — he leans on the wall and stays there.
That failure existed before and was invisible, because he simply walked through it.

**So the first answer is to reroute him, not to let him through.** A man who is solid,
within `SolidStuckNear` (1.8 m) of the wall line and covering less than `SolidStuckMin`
(0.5 m) for `SolidStuckTicks` (four ticks, ~4 s) is handed to the mod's own wall-aware
router. It cannot be fired from Lua — a behaviour only ever runs if an interrupt fires it,
and that interrupt lives in the scheduler — so `SolidAskDetour` raises a flag and
`NavFollowPoll` reads it:

> a man reported STUCK skips both the confirm count and the `NavFollowCooldown`.

Those two guards exist to stop a *blocked* man trading the behaviour tree back and forth
at the edge of every tent. A stuck man is a different case: his body is already against
the timber and he is going nowhere, so both guards are only delaying the one thing that
can help him. He gets `nav_goto` on the next poll.

Out of combat, if nothing takes him within `SolidDetourGrace` (five more ticks) he is
**let through** — the flag goes back to its shipping value for one pulse on him alone, he
is permeable for `SolidFreeTicks` (~5 s), walks out, and is made solid again on the far
side. That order of preference is the tent layer's, unchanged: **round it, else clip it,
never circle it.** A man walking through a wall looks wrong for a second; a man stuck
against it forever looks broken. Note what the release is *not*: it is not a global unlock.
The same per-character latch that makes the scoping possible is what lets exactly one man
through while the man beside him stays stopped.

### In combat he is left there, and that is the point

**A fighting man is never let through** (`SolidReleaseInCombat = false`, tested with
`soul:IsInCombatDanger`). The first shipped version did release him, and that was the bug
behind *"during battles they still phase through walls"* — not a failure of the collision
at all, but the release valve firing in the one situation where it can never be right.

The mechanism is worth spelling out, because it is a trap: the scheduler's detour arm is
gated `~$inCombat & ~$isCampActor & ~$wbStageGo & ~$navOrderGo & ~$wbLocked &
~$playerMounted`. A fighting merc therefore *cannot* be granted a reroute, however loudly
he asks — so a grace period followed by a release is, for him, a guaranteed phase-through
on a fixed timer. Combat is exactly where the release must not exist.

So he shoves at the palisade instead, which is what a siege looks like. If he has nobody he
can actually reach, that is the target picker's business — a wall already breaks line of
sight for *picking* a fight (see "TARGETING THROUGH WALLS" below) — and not something to
fix by opening the wall. `merc_solid_status` counts these separately.

Widening the scheduler gate so a fighting man can route round a wall is the next piece of
work if the shoving looks bad. It wants care: continuous re-routing during a fight is
exactly what the staged battle exists to avoid — though that judgement was made when NPCs
could still clip walls, so it is worth re-testing rather than assuming.

### But the engine can SEE it

`merc_wall_lab_see` asked `AI.CanMoveStraightToPoint` at 8, 12, 18, 25, 35 and 45 m, once
along the axis through the wall and once across it over open ground, and again with
nothing built:

| | 8m | 12m | 18m | 25m | 35m | 45m |
| --- | --- | --- | --- | --- | --- | --- |
| along the axis, wall at 15m | true | true | **false** | **false** | **false** | **false** |
| across it, open ground | true | true | true | true | true | true |
| along the axis, no wall built | true | true | true | true | true | true |

The flip lands between 12 m and 18 m, which is where the wall stands. Across the same
distances it never flips, so it is not a range limit; on the same bearing with nothing
built it never flips, so it is not the terrain. **The engine's own walkability query sees
a runtime-spawned wall.** What ignores the wall is the path FOLLOWER, not perception - so
"the engine cannot see it" was wrong, and only "the mover does not consult it" survives.

Two things follow. The mod's own `NavIsBlocked` is a 2D segment test against our own
corner list; `CanMoveStraightToPoint` is an engine answer that covers our walls, our
tents, vanilla geometry and terrain alike, and is worth using where a per-tick raycast is
affordable. And it makes the pathfinder's own danger-cost system worth a real try:
`AI.RegisterDamageRegion(entityId, radius)` is documented as "a spherical region that
causes damage (so should be avoided in pathfinding)", it needs no navmesh change, and the
ground either side of a wall is already walkable mesh. That is `merc_wall_lab_danger`.

### Why nothing that touches the navmesh can ever work

From the modding Discord, Warhorse's own Mortimer on how the navmesh ships:

> So it turns out that navmesh is not paked by default, there is another RC job that needs
> to be run after the level export

It is baked in Sandbox, inside a hand-placed `NavigationArea`, and exported into
**`recast.pak`** beside the level. It is data, not something the running game derives from
the world. Another modder hit precisely this mod's problem while editing a level:

> Seems like trying to regen navmesh once making changes to a level is automatically reset
> every time, npcs will just waddle through entities like its nothing.

So `wh_ai_AutomaticMNMRebuild` has nothing to rebuild from, `ai_MovementSystemPathReplanningEnabled`
has no change to replan around, and `AI.SetPFBlockerRadius` accepts the call and changes
nothing. A wall the player places at runtime cannot appear in a file baked before the game
shipped. Rebaking `recast.pak` is a real route for a *fixed* structure - a camp that always
stands in one spot, a castle - and no route at all for a builder that puts walls wherever
the player clicks.

What the engine does have, and a mod cannot reach: `C_NavMeshTileRuntimeAdjustmentTask`
and a Detour tile cache - the structure built for adding obstacles at runtime - with
**no Lua bind that adds one**. All 281 `AI.*` binds were enumerated; `SetPFBlockerRadius`
acts on an entity's AI object (a prop has none), and nothing else touches the mesh. That
is the one concrete ask worth making of Warhorse on the modding Discord: expose the
navigation system's runtime obstacle add/remove to Lua.

All of that is still true, and it no longer decides the outcome. **The pathfinder does not
have to know about the wall for the wall to stop a man** - his body can, and
`ac_disableLivingVsRigidCollisions` is what lets it. Read the two together: the navmesh
half means an NPC will still *aim* through a palisade, and the collision half means he no
longer gets there. The mod's own steering is what turns "stopped against the timber" into
"walked round to the gate", so none of the wall graph, the tent layer or the staged battle
is redundant - collision is the backstop under them, not a replacement for them.

### The property the walls were missing

Read this before the two sections below, which are the research that led to it.

`mercenaries_Prop` - the class every wall segment, gate, tower piece and house collider is
spawned as - had **no `AI` sub-table at all**. That single omission is why NPCs walked into
walls, and it is what "he's spawning it wrong" on the modding Discord was pointing at.

```lua
Properties = {
    AI = { bUsedAsDynamicObstacle = 1 },   -- mercenaries_Prop.lua, and in the spawn params
}
```

`bUsedAsDynamicObstacle` is the **only** navigation-related property in the entire shipped
script pak. `RigidBodyEx` carries it with Warhorse's own comment, *"This value is currently
used for the MNM Navigation System"*. In `WHGame.dll` (`release_1_5_1308617_856`):
`sub_30141B0` walks `Properties` → `AI` → the flag; `sub_300CB98` takes the entity's
bounding box, turns it into an obstacle cylinder, and `sub_2FF685C` adds it to the
**collision-avoidance set of every agent near it** - the local steering layer that makes an
NPC veer round a barrel. It is consumed when `wh_ai_ObstaclesAddToCollisionAvoidance` >= 1,
which [mercenaries_navobst.lua](../data/Scripts/mods/mercenaries_navobst.lua) arms while the
player is near a wall of ours (`merc_navobst 0|1|2`), together with `ai_ExtraAvoidanceRadius`
and `ai_MinActorDynamicObstacleAvoidanceRadius` for a margin.

Everything about it is data. It ships in the pak; there is no native code and no ASI loader
in the shipping path.

**What it is not.** This is local steering, not planning: a man veers when the obstacle is
inside his avoidance horizon, he does not choose a gate 40 m away. A wall is also a long
thin thing made of many cylinders, which is not what an avoidance solver is best at. So the
three layers are meant to run together - the mod's own A* plans for mod NPCs, this makes
anyone nearby steer off the timber, and [the collision fix](#it-was-never-the-navmesh)
stops whoever still arrives.

**A wall built before this change has no property and never will** until its segments are
re-spawned - the property is read when the entity physicalises. `merc_navobst_status`
reports how many standing segments carry it and says so; rebuilding the wall fixes it.

**Two ways to check it rather than take my word:**

- `merc_navobst_draw <npcName>` turns on the engine's own
  `ai_DebugDrawCollisionAvoidanceObstaclesForAgent` for one agent. If the wall cylinders
  are drawn, the segments are in that agent's obstacle set. This is the direct answer.
- `merc_navobst_selftest` walks the company along the wall for 15 s with the obstacles off
  and 15 s with them on, and reports how close they let themselves get to the timber.

### Into the navmesh: what the disassembly settled

Everything above makes a man's *body* stop at the wall. The pathfinder still aims through
it, because the navmesh ships baked and nothing a mod spawns is ever in it. Reading
`WHGame.dll` (`release_1_5_1308617_856`, via the corpus in [disassembly.md](disassembly.md))
settled what the engine can and cannot do about that at runtime.

**What ships.** `Levels/<level>/recast.pak` holds one `rdnavmesh_<source>_1.nav` per
navigation source (70 for the monastery, hundreds for Kuttenberg) - finished Detour tiles,
the `DNAV` magic at tile offset 0x3c - plus `groupcombinations_*.xml`. Warhorse's answer to
"the world changed" is to **pre-bake alternative layers and switch combinations** by quest
state (`klaster_enviro_nakazaclosedcryptwall` is a whole navmesh variant for one closed
wall). Nothing regenerates from geometry in the shipped game.

**The rebuild commands are stubs.** `wh_ai_RebuildNavmesh` and
`wh_ai_RebuildNavmeshFromCache` are registered, and both handlers resolve to `0x3B6E80` -
the shared empty function that fills every compiled-out vtable slot. The tile generator
thread (`C_NavMeshGeneratorUpdateThread`) and tile cache (`C_TileCacheUpdateThread`) exist,
but their only retail work is streaming tiles in and out.

**The one runtime door: obstacles.** `C_AIObstacles::AddObstacle(desc)` (`sub_C86F6C`)
takes `{x, y, z, radius, height, ignoreRadius, flag}` and, through `C_Navigation::vf3`, runs
a Detour `queryPolygons` under the cylinder (its status is compared against `0x40000000`,
`DT_SUCCESS`) and **sets bit 2 on every polygon it finds** - the 21-byte `dtPoly` this build
uses, flags in the last byte. The query filter's `getCost`
(`C_PathFindingBlockNavMeshFilter`, `0x44DF78`) then multiplies the cost of any flagged
polygon by `wh_ai_FindPathObstaclesMultiplier` whenever `wh_ai_FindPathUseObstacles` is on.
Both ship live: the multiplier at **3.0**, the switch at **1** (its registration passes
`default = 1`). `flag = 1` - the kind in-game dialogues use - also asks NPCs already walking
to replan. This is exactly why passers-by walk round a conversation, and it is instant.

It has **four callers in the whole binary**, and not one is reachable from data:

| caller | how it is reached |
| --- | --- |
| `sub_3BE760`, `sub_2EA8C00` | in-game NPC dialogues (`wh_dlg_CreateObstacle*`), sized by the participants |
| `sub_C87D44` | the dialogue manager again, one level down |
| `sub_2577C78` - `SequenceArea`'s `bCreate_Obstacle` | built by `C_CleanupManager::vf0` when a cutscene starts - a [confirmed dead end](cutscenes.md) |

No Lua bind, no behaviour-tree node, no Skald node. (`bUsedAsDynamicObstacle`, the property
the previous investigation pinned its hopes on, belongs to a different system entirely: the
per-agent collision-**avoidance** pass at `sub_300CB98`, which gathers entities within 15 m
of each NPC each tick and defaults the flag to *true* when the property is absent. It is
steering, not pathfinding, and the wall was already in it.)

### The native route, and why it is not the shipping one

*(Research, kept because it is the only way to reach the engine's **pathfinder** and is worth
having written down. It is NOT in the mod: it needs an ASI loader, which is not an acceptable
dependency for a mod people install normally.)*

A native plugin, ~200 lines, that registers one console command and calls `AddObstacle`
from it:

```
merc_navobst add <x> <y> <z> <radius> <height> [ignoreRadius] [flag]   -> MercNavObstacleResult
merc_navobst remove <id> | clear | status
```

[mercenaries_navobst.lua](../data/Scripts/mods/mercenaries_navobst.lua) drives it -
`System.ExecuteCommand` runs synchronously, the Lua reads the global - and drops a cylinder
every `NavObstSpacing` (1.5 m) along `NavWallSegments()`, which is the same list the mod's
own A* cuts against and already leaves the gate gaps out. While any stand it raises the
multiplier to `NavObstMultiplier` (100) and puts it back on clear. `WallRebuild` re-syncs
them, `WallClearSegments` drops them, and a level load forgets the ids (the registry belongs
to the level).

Three things about the plugin are worth knowing before touching it:

- **Nothing is hard-coded.** Three byte signatures over `.text`, each required to be
  unique: the `exec autoexec.cfg` site for `gEnv` (both shapes from the disassembly guide),
  the dialogue's `AddObstacle` site (`ignoreRadius=-1; flag=1; accessor(); [+0x160];
  [+0xA8]; vtable[9]; AddObstacle`) for the accessor and `AddObstacle`, and the
  `RemoveObstacle` wrapper (`cmp [rcx+0x108],-1`). The `E8` positions are found by walking
  the pattern, not counted by hand - counting them by hand produced two wrong offsets on
  the first build, and the resolver now also refuses any target outside `.text`.
- **It registers on the game thread.** `IGame::CompleteInit` (slot 4 of `gEnv->pGame`,
  the one that references `"C_Game"`) is hooked, the way kcd2db does it, because the
  console's command map is not thread-safe. Injected after init for a test, the hook never
  fires and the plugin registers directly after a 30 s grace.
- **Obstacles are cost, not walls.** A flagged polygon costs 100× more, so a man whose only
  route is through the palisade will still take it - but his body is stopped by the
  collision half above, and everyone with a gate to reach now plans for the gate.

Without the plugin every Lua function is a no-op that says so once in the log; nothing else
in the mod changes.

**Verified on a live level** (injected at the menu, save loaded, self-test on load): the
three signatures resolved to the corpus's addresses, `merc_navobst add 1368.5 2547.9 171.2
1.5 3.0 -1 1` returned obstacle id 0, `status` reported it held with the manager present,
and the game stayed up. The first build failed twice on its own bookkeeping, both worth
knowing: hand-counted `E8` offsets in the signatures (now walked from the pattern), and
`ExecuteBuffer` taken from the reference guide as slot 7 - that slot is `UnloadScript`, and
every Lua write was silently unloading a script that did not exist. Slot 6 is the one whose
body is `lua_load` + `pcall` ([disassembly.md](disassembly.md)). What this run does *not*
measure is a man's path bending round the cylinder; that is the walk test.

---

So `NavIsBlocked(a, b)` is a plain 2D segment-intersection test against the wall corner
list, and `NavPathAround` runs A* over a grid whose edges are cut where they cross a wall,
then string-pulls the result. It applies only near a camp (`NavActiveRadius`, 60 m) and
only to mod NPCs.

`NavSteerPoint` is the shared core — `nav_goto.xml` and camp patrol call it rather than
duplicating the logic. It used to have a third caller, `mercenaries_slots.lua`, which
computed each merc's follow slot in Lua and so could be bent round a wall for free. The
engine-formation rework deleted that file, and with it the only wall-aware follow the mod
had; `NavFollowPoll` below is what replaced it.

## The engine's AI script interface (the `AI` Lua table)

`CScriptBind_AI` registers **265 functions into the Lua global `AI`**, constructed by
`CAISystem::vf1`. It is live in retail — the base game's own scripts call twenty of them —
so a plain mod pak reaches all of it with no ASI loader. This mod used none of it until now.
Verified in game, not inferred: `merc_ai_probe` prints the table size and checks each bind.

Enumerate the whole table with
`python tools/disasm_query.py sql "SELECT name, impl FROM binds WHERE registrar=0xB96E60"`.
The constructor also registers the enum constants (`AIEVENT_*`, `AVOIDANCE_*`, `PFB_*`,
`AIPATH_*`, `NAV_*`, `STANCE_*` …) as Lua globals; dump them the same way through `xrefs`.

What is worth having:

| bind | what it does |
| --- | --- |
| `AI.SetCollisionAvoidanceRadiusIncrement(id, r)` | the PER-AGENT `ai_ExtraAvoidanceRadius`. Writes `[aiObject+0x854]`; honoured while `ai_CollisionAvoidanceEnableRadiusIncrement` is on (it ships on) and ramped in by `ai_CollisionAvoidanceRadiusIncrement{Increase,Decrease}Rate` |
| `AI.SetAdjustPath(id, 0\|1)` | let this agent's path bend round dynamic obstacles |
| `AI.SetForcedNavigation(id, vec)` | posts `AIEVENT_FORCEDNAVIGATION` (0x19) with a direction. A movement-layer override; zero vector clears it |
| `AI.CreateTempGenericShapeBox(centre, half, height, type)` | really does create a runtime AI shape (named `Temp%08x`) — but nothing was found that makes the pathfinder honour one |
| `AI.CanMoveStraightToPoint(id, pt)` | **do not trust as a walkability test.** It answered `true` for a point 40 m underground |
| `AI.IntersectsForbidden(a, b)` | **gutted** — reads its two vectors and returns through a shared `EndFunction`, testing nothing |
| `AI.SetPFBlockerRadius(id, type, r)` | per-AGENT blocker radius against the fixed `PFB_*` enum (player, dead bodies, explosives …), not arbitrary entities |

## Why avoidance "barely worked", measured

Live values read out of the running game (`merc_ai_probe`), not decoded from the binary:

| cvar | ships | why it matters |
| --- | --- | --- |
| `ai_CollisionAvoidanceTargetCutoffRange` | **3.0** | *"Distance from its current target for an agent to stop avoiding obstacles."* A man walking at something within 3 m of the wall stops avoiding exactly where the wall is |
| `ai_CollisionAvoidancePathEndCutoffRange` | **1.3** | the same for his destination |
| `ai_CollisionAvoidanceRange` | 5.0 | a palisade seen 5 m out leaves room to clip it, not to go round |
| `ai_CollisionAvoidanceObstacleTimeHorizon` | 1.5 | at a 4 m/s run that is 6 m of look-ahead |
| `ai_MovementSystemPathReplanningEnabled` | **0** | paths are never replanned, so an obstacle appearing changes no existing route |
| `ai_AdjustPathsAroundDynamicObstacles` | 1 | already on |
| `ai_CollisionAvoidanceEnableRadiusIncrement` | 1 | already on, so the per-agent increment is honoured |
| `ai_ExtraAvoidanceRadius` | 0 | no margin at all |
| `wh_ai_ObstaclesAddToCollisionAvoidance` | 1 | already on — never write this, it can only be lowered |

`mercenaries_navobst.lua` moves the two cutoffs to 0.5, widens range/horizon, adds a margin,
turns replanning on, and does a per-agent pass (`SetAdjustPath` +
`SetCollisionAvoidanceRadiusIncrement`) over everyone the collision layer already
enumerates — so raiders get it too, not only our men. All of it armed only near the camp
and restored on the way out, because these are global cvars.

## Combat locomotion is a different stack

`CombatMoveDecorator` → `CombatFollowerDecorator` → `CombatAction` never enters
`MovementSystem`, `FollowPath`, `IPathFollower` or the avoidance system at all. There is no
cvar, entity property or BT parameter that makes combat steering obstacle-aware; a
`C_DisableCollisionAvoidance` BT node exists but only to turn it *off*, and vanilla's own
melee tree does not use it. Note what this means: **vanilla NPCs also run at real walls when
chasing a target.** What they never do is pass through one. So the target for the combat
case is "collide and slide", which is the collision layer's job, not navigation's.

## Body collision: the cvar is the native mechanism, not a workaround

`ac_disableLivingVsRigidCollisions` has exactly one consumer in 291,812 functions:
`sub_83C630`, `CAnimatedCharacter`'s ColliderMode resolver, which reads the cvar's live value
out of the AnimatedCharacter cvar struct at `+0xC8` and never inspects the target entity.
So no collision class, physics proxy, mass or `PE_RIGID`/`PE_STATIC` change on the wall can
matter — which is why the lab's eleven candidates all failed. The palisade's
`$physics_proxy_proxy_palisade_wall_aaaa_013` node has **0 vertices**, and so does every
vanilla level-placed palisade, so the proxy is not the differentiator either.
`mercenaries_solid.lua`, pulsing collider mode per character near a wall, *is* the native
mechanism used the only way the engine exposes it.

## The navmesh: machinery live, door shut (tested, not assumed)

Correcting an earlier conclusion in this file: the navmesh rebuild code is **not** compiled
out of retail. Only the two console commands are no-ops, and their `ret 0` stub is shared by
37,295 vtable slots binary-wide, so landing on it proves nothing. Real and present:
`NavigationSystem` (69 of 73 vtable slots), both tile-generator paths (`sub_340F684` fresh,
`sub_34117E8` from cache), `rcBuildCompactHeightfield`, the layered `rcBuildHeightfieldLayers`,
Warhorse's `C_NavMeshGeneratorUpdateThread` and stock `NavigationSystemBackgroundUpdate`.

The switch is `wh_ai_AutomaticMNMRebuild` — *"Enables automatic rebuilding of nav mesh when a
change in level is detected"* — and it ships **0**.

**It was tested and it does nothing for us.** Two runs, `merc_mnm_test`: set the flag to 1
(the write takes, it reads back 1), spawn eight palisade segments 10 m ahead, watch for
150 s. Second run additionally forced `wh_ai_CryNavigationSystemEnabled` (ships **0** — the
system owning that generator is not even updating, because `wh_ai_OverrideMNM`=1 hands
navigation to Warhorse's own Recast path) from 0 to 1. In both runs the entire log contains
**no navigation-generation line of any kind** — the only navmesh activity is loading the
baked `recast.pak`. Whatever "a change in level is detected" means, a spawned entity is not
it. There is also no Lua bind and no BT node for regeneration; BT has read-only
`C_IsPointOnNavMesh` / `C_GetLastNavmeshPosition`.

So: the baked navmesh stays. Everything below is steering, not planning.

## ORCA is switched off in battle

`wh_ai_DisableORCAInBattle` ships at **1** — *"Is ORCA disabled during battle game context"*
— confirmed by reading it out of the running game. Collision avoidance is turned off outright
once a fight starts. That is the whole of "in combat it does nothing", and unlike the combat
locomotion stack (which genuinely has no data lever), this one is a single cvar.

`mercenaries_navobst.lua` sets it to 0 while armed, behind its own switch
(`NavObstOrcaInBattle`) because it is the one write here that changes how a *fight* behaves
rather than how someone walks — men who avoid each other are men who may not close to swing.
Armed only inside the camp region, restored on the way out, like everything else in that
module.

## One obstacle per stretch, not one per plank

Obstacle registration is strictly **per entity**. `sub_2FF685C` walks all of one entity's
physics parts and merges them into a single footprint — an oriented box from the physics OBB,
flattened to floor height — but separate entities never merge. A palisade of forty 2.75 m
props is therefore forty independent candidates with a numeric gap between each pair that a
velocity can be threaded through, and short boxes in a row do not join into a wall.

`NavObstBlockersBuild` spawns **one invisible collider per straight stretch** of each run
(`mercenaries_Prop` + a crate mesh + `DrawSlot(0, 0)`, the same recipe the camp house uses),
measuring the mesh once with `Entity.GetLocalBBox` rather than guessing its size. Forty
segments become four to six continuous obstacles. The visible props are untouched.
`merc_navobst_blockers 0|1`.

## Why NPCs ignored the walls: the obstacle query excludes static bodies

This is the root cause, and it makes everything above it in this file that credits
`bUsedAsDynamicObstacle` on a spawned prop wrong.

The obstacle candidate gather `sub_2F52A5C` asks the physics world for entities with
`entity_query_flags = 0x50006`:

```
02F52AB2  mov  dword ptr [rsp + 0x20], 0x50006
02F52ABA  call qword ptr [rax + 0x110]
```

`0x50006` = `ent_allocate_list | ent_ignore_noncolliding | ent_rigid | ent_sleeping_rigid`.
**`ent_static` (bit 0) is not in the mask.** Wall segments spawn as `mercenaries_Prop`, whose
`Properties.Physics.bRigidBody = false` gives `PE_STATIC`, so they are never returned as
candidates: `sub_300CB98` is never called on them and `sub_30141B0` never reads the flag.
**`bUsedAsDynamicObstacle` on a static entity does nothing at all.** Three independent
skeptics failed to refute this.

The chain is not a level-load sweep, so spawn timing was never the issue:
`sub_30141B0` <- `sub_300CB98` <- `sub_300C364` <- `sub_2FF9DFC` (throttled per-agent cache
refresh) <- `CPuppet::AdjustPath` / `CPipeUser::HandlePathDecision` (vtable slot 105), plus
`CAISystem::vf91`. Note `C_Obstacles::vf2` is the destructor, not a per-tick consumer -
an earlier note in this file had that wrong.

**The fix:** the obstacle-bearing entity must be a rigid body; a resting one qualifies
(`ent_sleeping_rigid`). `EntityCommon.PhysicalizeRigid` picks `PE_RIGID` only on
`Properties.Physics.bRigidBody == true`. `bResting` is tested `== 0`, so any other value
leaves it asleep. `bRigidBodyActive` is an ENTITY FIELD (BasicEntity sets it true), not a
property - putting it in a Physics table does nothing. Measured in game: the blocker reads
`GetMass() = 2.47e6` where a control `PE_STATIC` prop reads `0`, and it holds position
(drift 0.11 m, unchanged between 6 s and 18 s).

### The obstacle pool is 32 slots, globally

`sub_2FF6618` pushes into a single hard-capped ring (`.data` `0x1855881D8` begin /
`0x1855881E0` end / `0x1855881E8` cap) shared with every other obstacle in the world. A
forty-segment palisade could never have fitted even as rigid bodies. That is why the blockers
are one-per-stretch and why their chunk length is chosen from `NavObstBlockerBudget` (default
8) rather than a fixed metre count: a long wall gets longer blockers, not more of them.

### Two other things worth knowing

`ai_CollisionAvoidanceClampVelocitiesWithNavigationMesh` ships at **2**, and its full help
text is *"Enable/Disable the clamping of the speed resulting from ORCA with the navigation
mesh / 2 - means disabling avoidance for agents that are not on nav mesh"*. An agent standing
off the navmesh gets no avoidance at all.

The floor gate in `sub_300CB98` was investigated as a suspect and **cleared**: it tests the
AABB's max.z and min.z against the found floor with 0.5 m / 2.0 m thresholds, and a palisade
sunk 3 m still stands ~3 m proud, so it passes comfortably. (The mesh is ~6.0 m tall, not the
4.5 m assumed earlier - measured from the shipped `.cgf`.)

## Combat: no data-only fix exists (closed)

Three separate things were checked and all three close the door:

1. `wh_ai_DisableORCAInBattle` is **event-latched, not live**. It is read only when the game
   enters or leaves a battle context - `C_NavigationGameContextListener::vf0`/`vf1` (RVA
   `0x3411F88` / `0x3411FAC`) each re-read it and cache the result into one global bool at
   `.data:0x53339B0`, which `CAISystem::vf14` then tests. Setting it mid-session changes
   nothing until the next context transition.
2. "battle" is a **scripted game context**, not "any combat". It is entry 2 in a hand-authored
   vocabulary parsed by `sub_BE4BE4` (`none, ipl, battle, indoor, nodog, noPlayerCombat,
   disableHuntAttack, forceCombatSystemAmbientLOD, disableORCA, disableHearing, ...`), set by
   Skald `SetGameContext` / `GameContextTrigger` nodes. Nothing in the DLL flips it when
   ordinary combat starts, so the mod's raids almost certainly never enter it.
3. Combat locomotion has its **own** obstacle term - `WH_AI_CombatMove_ObstacleWeight`,
   `M1ObstacleWeight`, `CheckRadius`, looked up by `sub_30AAFF0` - but those are **not cvars**.
   Read live in game they answer `<absent>`, while `WH_AI_CombatMove_ForeignTargetRepulsion`
   from the same family answers `0.6`. They are baked tunables, unreachable from a mod.

So a fighting NPC cannot be made to route around a wall from data. The ceiling in combat is
collide-and-slide (`mercenaries_solid.lua`) plus faster stuck recovery. Correcting an earlier
claim in this file: combat locomotion does *not* "never enter the avoidance system" - it has an
obstacle term of its own; it just cannot be reached.

## `stuckThreshold`: a real, data-reachable give-up timer

`stuckThreshold` is a field of the `additionalMoveParams` BT variable type, and the base game
uses it - `values="stuckThreshold(5)"` in `AI/profession/farmer/so_field.xml`. Multiple fields
are comma-separated (`destChangedThreshold('500'),continueWhenHalting(false)` in
`AI/crime/followhelpingnpc.xml`), and the same fields are also settable from a BT `<Expression>`
(`$additionalMoveParams.destChangedThreshold = '1s'`).

Stuck detection is `CNavPath::m_stuckTime` against `stuckDetectionThreshold`; the related live
cvars are `wh_ai_StuckDetectionAllowAnyMovement` (1), `wh_ai_MovementTeleportWhenStuck` (2),
`WH_Move_OffMeshStuckDetectionMultiplier` (2). This is what "they shove at the wall for ten
seconds and then go round" looks like, and it is independent of the obstacle system entirely.

The mod's seven `additionalMoveParams` blocks now carry `stuckThreshold(3)`.

## Can the navmesh be changed from a mod? The full audit

Five lanes, each adversarially verified. Short answer: one route is genuinely reachable, and it
still does not solve the problem.

**`AddObstacle` IS reachable from mod content** - the earlier "none of its four callers is
reachable from data" verdict was wrong. Confirmed chain, byte-level, unrefuted by three
skeptics:

```
C_Human::vf14 (0x8CFAE8) -> sub_8D0040 -> sub_3BDEF0 -> sub_C072C0 -> sub_C06238
  -> sub_C87D44   [cvar wh_dlg_CreateObstacle, default 1 = ON, registered in sub_E3DE3C]
  -> sub_C86F6C   AddObstacle
```

Any active in-game **dialogue** places a navmesh obstacle at its participants' positions, at
retail defaults. This mod already ships dialogues, so it is already happening.
(`wh_dlg_CreateObstacleForIngameNpcDialogues` is the sibling cvar and ships **0**.)

**Why it is not a fix, all confirmed:**
- It is a **cost multiplier, not a block**. The flag bit `0x02` is not in `passFilter`'s include
  or exclude masks; a flagged polygon is merely `wh_ai_FindPathObstaclesMultiplier` (3x) more
  expensive. Crossing a 1 m wall line at 3x cost still beats a 40 m detour.
- It is **transient**, scoped to a live dialogue instance (matched create/destroy:
  `sub_C88020` -> `RemoveObstacle`/`sub_D326A4`). Blocking ground means keeping a dialogue
  running there forever.
- **Combat movement never reaches the pathfinder at all**, so no poly-cost change touches it.

**FlowGraph `AI:RegenerateMNM` - the format is moddable, the trigger is not.**
`CFlowGraphModuleManager` really does scan `Libs/FlowgraphModules\` through `ICryPak`
(`sub_B915D8`, path built in `sub_B90410`), and real loose modules ship there
(`HORSEGetOnHorse.xml`, `IsDay.xml`, `AudioControl.xml`, ...). One of them contains an
`AI:`-category node (`AI:AnimEx`), and a module's graph is an ordinary `CFlowGraph` using the
one global node registry - so the file format would accept an `AI:RegenerateMNM` node. But
there is **no Lua bind, console command or entity property that starts a module**: the binds
table has zero `Flow`/`Graph`/`Module` entries, `CFlowGraphModuleManager::vf6`
("Module:Start_%s") has zero direct callers, and the only native trigger is a `CallModule` node
inside an already-running graph. Entity-attached graphs (`CFlowGraphProxy`) are export-baked
into level data - "FG was disabled on export".
The one untested pak-only idea: override a vanilla loose module that already fires (e.g.
`Libs/FlowgraphModules/IsDay.xml`) and splice the node onto its Start pin. Not tested, and note
the node has **no spatial ports at all** - only "Start" - so it is a coarse regenerate-
everything with unknown cost, not a tile-local API.

**The other routes, all confirmed dead:** shipping navmesh data is out (recast.pak comes from a
full Sandbox level export, and `groupcombinations` variants select by named quest flags at fixed
hand-placed spots - never by runtime position, so they cannot know where a player-placed camp
is). The only other live mechanism is the SmartObject off-mesh link system
(`OffMeshNavigationManager`, cvar `wh_ai_AreaToNavSOAllowedLinkNames` default "entrance"), which
creates navmesh **connections**, not blocks - the wrong direction. `wh_ai_RebuildNavmesh` and
`wh_ai_RebuildNavmeshFromCache` remain `ret`-stub no-ops.

## Tents and other camp obstacles

The palisade is not the only thing a merc walks through — the camp's own tents, the
player's hut and the fires are all spawned at runtime and equally invisible to the
engine's pathfinding. They are handled by a **separate, local layer**, and the split is
the whole design:

- **the wall** is a global problem. You cannot see round it, so it goes in the A* graph.
- **a tent** is a local one. You can see past it in a step or two, and it must NOT go in
  the graph: a camp packs six tents onto a 3.9 m ring (`CampTentRingRadius`), so cutting
  graph edges against them seals the fire circle, every route inside camp comes back
  `NO ROUTE`, and a man with no route beelines — which is the clipping this exists to
  stop, now with the wall routing broken as well.

So `NavIsBlocked` still means *a wall is in the way*, and everything built on it — the
graph, the gap sweep, `NavTargetBlocked` — is unchanged. `NavPathBlocked` is the wider
question (wall **or** footprint) and only the things that steer a man ask it.

Obstacles are registered as the props go down (`NavAddObstacle`) and cleared with the
camp. Each is an oriented rectangle in the camp builder's own frame — `half.w` across the
facing, `half.h` along it — tested with Liang–Barsky.

**They use their own footprints, not the placement boxes.** `CampTentFootHalf` asks how
much clear *ground* a tent needs and claims 2 × 4.5 m of it; steering men round that
walls the fire in. `NavTentFootHalf` (2.1 × 2.9 m) is sized to the mesh instead.

### Rounding one

`NavAvoidPoint` hops to a corner of the box in the way, re-tests, and does that at most
`NavObsMaxHops` times. Three things are load-bearing, and each of them was a bug first:

- **the side is latched** (`rec.obsSide`, keyed by the obstacle) until that obstacle stops
  blocking. Choosing the cheapest corner afresh each tick makes him alternate between the
  two near ones and walk on the spot, because the cheapest corner is always the one he
  just stepped away from.
- **corners are tried far first.** The far corner skims the side of the tent and comes out
  past it; the near one is the fallback that gets him clear of the box's slab so that the
  far one becomes reachable next tick.
- **a corner he is standing on is pushed out to `NavObsCornerMin`** rather than skipped.
  Skipping it leaves nothing to aim at and he walks straight through; aiming at it is a
  zero-length step and he stops dead.

`NavObstacleHit` ignores an obstacle the walker is **inside** — he walks straight out
rather than being shoved deeper. That test is the *raw* footprint, not the padded one: a
man merely inside the clearance margin must still be steered, or brushing a corner
switches avoidance off exactly where it is wanted.

A deflection is dropped if it would cross a wall. A tent is never a reason to leave the
side of the palisade you are on.

### The give-up

Local rounding cannot find a gap on the far side of a ring of tents — nothing here plans.
`NavAvoidSteer` therefore watches for deflection that gains no ground: `NavObsGiveUpSecs`
(9 s) without getting `NavObsProgress` nearer the target stands the layer down for
`NavObsMuteSecs` (6 s) and lets him walk.

That is deliberate, and the order of preference behind it is: round it, else clip it,
never circle it. A man walking through a tent looks wrong for a second; a man orbiting one
for ever looks broken, and a man stuck against it is worse than either.

### Following

`FormationFollower` and `CrimeFollower` both choose their destination inside the engine,
so a following merc cannot be steered round anything — which is why a squad walks through
the camp it just paid for. `NavFollowPoll` takes him off them for the length of a detour
and hands him to `nav_goto`, which we do steer.

It is deliberately grudging, because firing that interrupt evicts the follow behaviour and
the scheduler has to re-arm it (`FollowStalled`, from `NavGotoEnd` — without that he is
left with a latch saying he is following and nothing running, which is the standing-still
bug). So it fires only near camp, only when something is genuinely in the way for two
polls running, and not again for `NavFollowCooldown` after the last detour ended. Never
while mounted: re-firing an interrupt over a rider throws him off the horse.

`merc_nav_follow 0` turns it off; the tent layer stays on.

### What is still not covered

A camp actor walking to his own stool, bed or activity spot Moves to a fixed mark
published once (`campActPos`, `campFurniturePos` in `camp_actor.xml`), and bending a
destination that has to be hit exactly would break the sitting. Those walks are short and
laid out to run between tents rather than through them, so they are left alone. Giving
them the patrol treatment — a steering point plus an arrival latch — is the way in if it
ever needs doing.

### Corner cutting

`NavSwitchR` (7 m) is deliberately wide so corners come out smooth instead of stop-start.
Next to a palisade that same width will cut *through* the wall, so the skip-ahead is only
taken when the shortcut is clear (`NavIsBlocked(me, nextWaypoint)`).

That test must be skipped once the NPC is actually **on** the waypoint. Leg-to-leg is clear
by construction (A* plus string pull), but from a body-width off to one side the next leg
often reads as blocked — so refusing to advance there leaves him steering at his own feet,
stalled on a path point forever.

### Why they used to halt at every waypoint

The `Move` node **ends** when it reaches its destination, and the `<Loop>` around it then
restarts it from a standstill. That restart is the halt. A man marching in column hits it
constantly, because his destination is the spot he is already standing on.

So the aim is never a point he is about to reach: while there is route left,
`NavAimAhead` pushes it on toward the next waypoint (or, for a follower, toward the
leader's own mark), keeping it at least `NavMinAim` away. It is bounded by that next point,
so it cannot run away from him, and it is dropped entirely on the final approach — arrival
is Lua's decision (`gotoDone`), never the node's.

**Do not tighten `stopWithinDistance` in `nav_goto.xml` to achieve the same thing.** It was
tried (0.5 → 0.25) and the NPCs stopped moving altogether: a stop radius the engine cannot
satisfy fails the `Move`, and the `Parallel` is `failureMode="Any"`, so that failure takes
the whole tree down and the man just stands there. Smoothing belongs in Lua.

### Lanes

Everyone routing round the same wall gets identical waypoints out of A*, so they walk single
file and shove each other. Each NPC holds a fixed **lane** — a sideways offset from the leg
he is on (`NavLaneWidth`, 1.6 m) — so a group spreads into a band.

The offset is re-checked against the wall every tick and dropped whenever it would put him
inside one, so at a narrow gateway the lanes collapse to zero and they file through. Lanes
never affect *progress*: the advance test measures against the true waypoint, not the offset
one. `merc_nav_lane 0` restores single file.

### Movement is only as good as the engine's

Our routes guarantee each leg is a clear straight line. The engine still walks its own
navmesh between waypoints and knows nothing about the wall, so a very long leg can bow
through one. Short legs and lanes keep it close to our line; this is the residual failure
mode when someone clips a corner.

## Why battles are staged

Continuous wall-aware pathfinding during combat never held up. Engine combat movement
keeps steering at the target every tick and no amount of re-routing outvotes it, so an
NPC would run along the wall and then turn into it.

Instead, the fight is staged. `WBTick` (700 ms) runs a three-phase machine:

- **idle** — no attackers within `WBTriggerRange` (55 m). Wall rules apply (patrol routes
  follow the wall, no targeting across it) but nobody is being marshalled.
- **staging** — both sides walk to muster points at the gaps. Our combat fires are
  suppressed (`wbLocked`) so nobody starts early. Nothing physically stops a man walking
  through the wall — only his orders do.
- **battle** — all wall rules OFF. Normal combat, clipping tolerated.

Staging ends on contact, or when `WBStageQuorum` (90%) of **each side** has arrived and
`WBStageGrace` (2 s) has passed, or when the staging allowance runs out. The quorum matters:
waiting for the last man meant one straggler with a bad route held the whole line at
attention. See "When the fight opens" below.

### Gaps and gate radius

**Gates come first.** If the camp is walled and has any gate, `WBGateGaps` builds the gap
list straight off the gates — one gap per gate, on the bearing from the camp centre, as
wide as `GateWidth` — and the ray sweep below never runs. Attackers therefore always
muster in front of a gate and come in through it, and a *shut* gate is still a gap: it is
where the fight will be, not a hole in the pathing. Without that, a sealed camp has no
walkable bearing at all and falls through to the "wholly enclosed" stand-in, which points
at due east rather than at anything the camp actually has.

The rest of this section is what happens on a walled camp with **no** gate.

A gap is a bearing along which you can leave camp without crossing a wall, found by a
72-ray sweep from the camp centre — that works for a ring left open, several separate runs,
or a deliberate gateway. The sweep passes `margin = 0` so a narrow gateway is not sealed
shut by the clearance margin.

Muster points sit at the **gate radius**, measured per gap by raycasting the two closed
bearings that flank the opening. Using `NavWallExtent()` instead — one scalar radius,
i.e. a circle — put "inside the wall" *outside* it on the short axis of any non-circular
wall, and men walked through the palisade to reach a spot on the wrong side.

### Battle lines

Each man gets his own slot rather than a shared point per gap, or they pile into a heap.
Slots run along the wall (`gap.right`), `WBLineSpacing` apart, with back ranks standing off
by `WBRankSpacing` — outward for attackers, further into camp for defenders. Men are sorted
by their projection onto the line so nobody crosses a comrade to reach his place.

Rank width is **the gap's own width**, not a fixed number: the chord across the opening
divided by `WBLineSpacing` (`WBRankWidth`). A narrow gateway therefore produces a single
file, a wide breach a broad rank, and the block runs back as many ranks as the headcount
needs. `WBLineWidth` is only a hard cap.

### Marching in column

Independent movers aimed at nearby points shove each other sideways, and next to a palisade
that is enough to push a man through it. So a side does not walk to its slots as N separate
movers: the man with least ground to cover **leads**, routing normally, and the rest trail
him in file at `WBColumnSpacing`, their destination measured back along his line of march
(`trailEnt`/`trailBack`/`trailAim` on the nav record). One route, one set of legs.

The block they march in is the block they will fight in — same rank width, same files — so
it is a couple of metres deep rather than a single file twenty metres long that comes apart
the moment one man is slow. Offsets are measured relative to the leader
(`trailBack`/`trailLat`), back along his heading and across it.

A leader whose block has strung out **stands fast** until it closes up: `WBColumnCheck`
watches the worst-placed follower and sets a hold past `WBColumnStretch`, but only after
`WBStretchTicks` consecutive checks and releasing at half of it — a leader who halts the
moment the block loosens produces a rhythmic stop-go march instead of a fix. He also never
waits longer than `WBHoldMax`, or one man stuck on scenery would hold the whole column at a
standstill for the rest of the approach.

When the leader comes within `WBFormBreak` of his mark the column breaks and everyone peels
off to his own place in the line. `WBStagePoll` owns that switch — it is the only place that
knows which order a man should be under, so `WBDispatch` no longer issues orders at all, and
a walk already under the right order is never re-issued (that would restart the `Move` and
cost the corner he is in the middle of).

A trailing man never reports arrival: his mark is a moving point, and ending there would
tear the order down and re-issue it every poll.

### When the fight opens

Whichever comes first:

- **contact** — any attacker within `WBEngageDist` of any defender, *once the attacking
  side has met `WBStageQuorum`*. That distance is about the width of no-man's-land between
  the two lines, so without the quorum test the first raider to reach the gate would open
  the fight and the rest of the column would feed in behind him a man at a time. They
  gather, then go in. A lone attacker is his own quorum, so an ordinary enemy walking up to
  the camp still starts a fight the moment he is in reach. Everyone still short of their
  slot is then released and walks in under their own behaviour, like any other fight
- **the attacking side alone formed**, held for `WBAttackerGrace` (3 s). This is the one that
  normally fires. `WBQuorumMet` tests *both* sides, so a raid that had marched in and drawn up at
  the gate used to stand there until the company's own line formed, or until the whole staging
  allowance ran out — `WBStageTimeout` plus the march budget, about a minute for a raid staged
  120 m out. That was the "raiders wait forever at the gate" bug, and it was never the intent: the
  rule is that the *attacking* side must be formed before it commits, which is exactly what the
  contact arm above already says. Opening early costs the defenders nothing they had, because
  entering `battle` releases every staging assignment anyway — mercs still short of the wall walk
  the rest of the way and fight as they arrive. The clock starts when they *form*, not when staging
  starts, so it measures standing at the gate rather than the march in
- both lines formed (per-side quorum) plus `WBStageGrace` (0.5 s)
- the staging allowance expiring — `WBStageTimeout` + `far / WBMarchSpeed`, the safety net only

The quartermaster is a defender. He is not in `ActiveMercs`, so before that he was the one
man with no muster point and no combat lock, and charged through the wall alone.

Turning `battle` on also runs `WBForceGates`: every gate the attackers were assigned to is
swung open, so a raid that formed up outside a barred gate comes in through it instead of
standing at a solid wall. Only the gates under attack move — read off `WBAssign`, which is
why it runs before the assignments are dropped. Gates elsewhere on the perimeter stay shut.

### Movement is BT-driven

`NavGotoRequest` only *records* the destination. Movement happens when a behaviour tree
fires the `nav_goto` interrupt, and only a tree can do that — each scheduler has a staging
loop that fires it while `WBStagePoll` says the NPC has somewhere to be. Remove that loop
and staging silently assigns positions nobody walks to; combined with the combat lock, the
whole camp stands still.

## Raids

`merc_raid [count] [group] [distance]` spawns a hostile force well outside the camp,
already drawn up in the block it will fight in, and lets the ordinary staging machinery
march it in. With a wall it approaches on the bearing of a randomly chosen gap, so the
march reads as an approach to a gate rather than a lap of the palisade; without one there
is nothing to march to, so it comes out of a random quarter and the staged system stays
out of the way entirely.

Everything after the spawn is the normal path — the force counts as attackers, staging
assigns it that gap, it marches in column and the fight opens when both lines are formed.

**A raid force is marshalled exactly once.** `WBSetPhase("battle")` sets `WBRaidStaged`, and
`WBAttackersNearCamp` stops counting the force from the raid roster after that; from then on it is
found the ordinary way, by the `WBTriggerRange` sphere query, if it is near the camp.

Without that latch the machine **loops**, and the log reads like this:

```
staging timed out at 18/35 - starting anyway
phase -> battle
phase -> idle
14 attacker(s), 21 defender(s) over 1 contested gap(s)
phase -> staging
```

Staging times out with the column still short of the camp → the fight opens → the `battle` phase
does not count the raid force, so it sees an empty field → it goes quiet back to `idle` → and `idle`
counts the force again and marshals the whole camp a second time. Round and round: the raid never
resolves, the force never dies, and `RaidBusy` stays true for ever.

That is what **"the first `merc_raid_now` works and the second does nothing"** actually was — the
second was refused with `a raid is already under way`, by a raid that could never end.

### Scheduled raids (`mercenaries_raids.lua`)

`RaidTick` fires a raid roughly every `RaidDaysBetween` days (2, ± `RaidDayJitter` so it is
not clockwork), and only when:

- the camp is pitched **and the player is standing in it** (`RaidCampRange`, 45 m) — a raid
  nobody is there to fight is just a band of men standing in a field
- no fight is already under way (`WBPhase` is idle and no raid force is still alive)

A raid force that has been standing for `RaidStaleSecs` (5 min) is **cleared** by `RaidBusy` rather
than merely ignored. Something wedged, or a few raiders broke off and wandered — either way it must
not stop the company ever being raided again, and leaving the stale band standing while a fresh one
marches in would stack two raids on the camp.

`merc_raid_now` does **not** defer to any of this: it clears whatever is still standing and launches
a fresh raid. The command exists to make a raid happen, and refusing is not that. The *scheduled*
path still defers to `RaidBusy`, because a raid landing on top of the one the player is fighting is
not something the clock should be able to do on its own.

Barred gates used to stand the raid watch down; they no longer do. `RaidSealed` survives
only as a line in `merc_raid_status`.

### The roster

Who turns up is rolled at launch from `RaidRoster`, **every group equally likely**. The
company's own quality no longer picks the enemy — what varies is `share`, the number of
raiders per living man in the company, because the groups are nowhere near each other in
worth:

| Group | Key | Share | 13-man company faces |
|---|---|---|---|
| Sigismund's knights | `knight` | 0.5 | 7 |
| Sigismund's soldiers | `sigi` | 0.6 | 8 |
| Prague regiment (Kuttenberg) | `prague` | 0.6 | 8 |
| Cumans | `cuman` | 0.7 | 9 |
| Bandits | `bandit` | 1.0 | 13 |
| Looters | `looter` | 1.0 | 13 |

Knights at even numbers would be a massacre and looters at even numbers a warm-up, so the
count is what levels them — half a dozen knights and a full dozen looters are both a fight
for the same company. `RaidPick` rolls the group and sizes it in one call; the result is
clamped to `RaidMinCount`..`RaidMaxCount` (**3..14**), so a four-man camp is not walked
over and a full one is not besieged. Knights carry no archer souls, so a knight raid is
all melee (`SpawnEnemyAt` downgrades the archer slots by itself).

Because the group is only rolled when the raid launches, `merc_raid_status` cannot name it
in advance — it prints the whole draw instead, sized against the company you have now.

The next raid day is saved (`QMRaidNextDay`) so it survives a reload, and a clock that jumps
backwards re-arms rather than firing immediately.

A raid marshals the camp **whether or not there is a wall**. Without one there is nothing to
route around, but the attackers still have to be marched in: `WBTick` used to bail out
entirely when `#WallMarks < 2`, so a force that spawned out of perception range was never
given orders and simply stood in a field forever. With no wall, `NavFindGaps` returns one
notional gap on `WBOpenBearing` — the bearing the raid came from — at `WBOpenCampRadius`,
so both sides form up facing each other and walk straight there. Ordinary wandering enemies
near an unwalled camp are left alone; only a deliberate raid does this.

Rules for the long approach:

- a raid force counts as attackers at *any* range, but only before the battle phase —
  otherwise one survivor running for the hills holds the camp at battle stations forever
- the staging allowance scales with the ground the furthest man has to cover
  (`WBStageTimeout` + distance / `WBMarchSpeed`), since a force crossing 120 m cannot form
  up inside a flat 12 s
- the quorum is measured **per side**: the defenders are already standing in camp while the
  raiders are half a field away, and a pooled count would open the fight on their behalf

## Battle music — not possible from a mod quest

KCD2 drives music from named **states**, switched by a `SkaldBoxProbe` whose `IsActive` is
a Skald bool. The main-quest battles do exactly this — `utokNaMalesov/.../tvrz/hudba.xml`
toggles `STORY_M44B_ATTACK_PHASE_1` and `_2`; the courtyard finale uses
`STORY_M51_BATTLE_6_COURTYARD`. Generic ones exist too, e.g. `SKIRMISH_FRIENDLY`.

Lua cannot set a Skald bool, so the bridge has to be something Skald can observe. The
obvious one is the player's inventory, via the vanilla `utils.item.itemclasstrigger_playerinventory`
module. **That does not work, and it takes the whole mod's quest graph down with it:**

```
[Error] Concept xml file contains undefined rttr type 'itemclasstrigger_playerinventory'
[Error] Object factory was not able to create new '...battle_music::itemclasstrigger_playerinventory'
DeserializeObject returned invalid object for node 'battle_music' of type 'Module'
...
[Error] Unable to load concept graph xml Quests/mercenaries.xml
```

**A mod quest can only use primitive Skald node types.** Vanilla *sub-modules* — anything
defined as its own `<Module>` in the base game's quest tree, referenced by `Namespace=` —
are not registered types for a mod's concept graph. Referencing one fails deserialization
of that node, which fails its module, its quest, its level, and finally the entire
`Quests/mercenaries.xml`. Every dialog in the mod goes dead, not just the new feature.

So: **never reference a vanilla sub-module by namespace from the mod's quests.** If a Skald
node type is not a primitive (`State`, `Switch`, `Function`, `SkaldBoxProbe`, `Timer`,
`PlayerItem`, …), it cannot be used. Any new quest work should be smoke-tested by checking
the log for `Unable to load concept graph xml Quests/mercenaries.xml`.

The level data was searched for a route that avoids Skald entirely, and does not have one.
`objects_mission0.xml` has 408 `AudioAreaAmbience`, 32 `AudioTriggerSpot`, 16
`AudioAreaRandom` and 9 `AudioAreaEntity` entities — all spawnable classes — but every one
of their 74 distinct `audioTriggerPlayTrigger` values is an ambience loop (`a_l_forest02`,
`a_l_army_camp01`, …). There is no music trigger among them.

The feature was removed. What is left to try, if it is ever picked up again: a probe built
only from primitives that can observe some Lua-settable state, driving `SkaldBoxProbe`.

<details>
<summary>Superseded design (kept for the reasoning only)</summary>

The bridge was an item: `WBMusic` put a token in the player's pocket when the battle phase
opened and took it back when it ended, and a `battle_music` sub-module of the background
quest watched for it, held the result in a Tribool, and fed `.True` to a `SkaldBoxProbe`.

Two things learned along the way that still apply elsewhere:

- `GetCountOfClass`, `CreateItem` and `DeleteItemOfClass` live on **`player.inventory`**,
  not on `player`. Calling them on the entity throws, and inside a `pcall` that looks
  exactly like a feature silently doing nothing.
- a Tribool `State` does expose `.True` as a bool, and `ontargetamountacquire` / `onlose`
  are real output ports — the design was sound; only the module reference was not.

</details>

## Commands

| Command | Use |
| --- | --- |
| `merc_raid [count] [group] [distance]` | spawn a raid far out and march it to a gate |
| `merc_raid_clear` | remove the current raid force |
| `merc_raid_now` | launch the scheduled raid immediately |
| `merc_raid_status` | when the next raid is due, and what it will be |
| `merc_raid_arm 0|1` | turn scheduled raids off or on |
| `merc_wb_status` | phase, gap count, staged N/total, and every man's distance to his slot |
| `merc_wb_gaps [menPerSide]` | mark the battle lines with barrels; logs each gate radius |
| `merc_wb_line [spacing] [perRank] [rankDepth] [outOffset] [inOffset]` | line shape |
| `merc_wb_start` / `merc_wb_battle` / `merc_wb_idle` | force the phase |
| `merc_wb_enable 0\|1` | marshal both sides to the gaps at all — **ships ON** |
| `merc_nav_build [radius] [spacing]` | rebuild the graph |
| `merc_nav_show` / `merc_nav_test` / `merc_nav_clear` | visualise and test routes |
| `merc_wp_radius <switchM> <arriveM>` | corner smoothing |
| `merc_nav_lane <metres>` | lane spread off the shared route; 0 for single file |
| `merc_nav_obs` | mark the tent/hut/fire footprints mercs route around |
| `merc_nav_avoid <metres>` | how far outside a footprint a route is aimed |
| `merc_nav_follow 0\|1` | route following mercs round camp geometry |
| `merc_wall_lab [case]` | run the wall-blocking matrix: build a wall, send a test NPC at it, record whether he went through |
| `merc_wall_lab_cases` / `_report` / `_stop` | list the matrix, print the last results, abort and restore every cvar |
| `merc_nav_engine` / `_arm 0\|1` | report or arm the engine obstacle cvars |
| `merc_nav_blockers [r] [type]` | try AI.SetPFBlockerRadius on every wall segment |
| `merc_nav_aim <metres>` | how far ahead the steering point is held; 0 brings the halting back |
| `merc_nav_debug 0\|1` | nav logging on the hot path |
| `merc_wall_matrix <group\|all> [cell] [percol]` | gallery of every base-game stone wall (no arg lists the groups) |
| `merc_wall_matrix_clear` | remove the gallery |
| `merc_wall_mx_where` / `merc_wall_mx_use` | name / build with the gallery piece you are standing at |
| `merc_wall_mx_list <group\|all>` | print a group's mesh paths |
| `merc_wall_mx_yaw <deg>` / `merc_wall_mx_up <m>` | spin or sink every gallery piece and respawn |

**Marshalling ships ON** (`WBEnabled = true`), and it is the only thing that actually routes a
fighting man round a wall. It was briefly off to test whether NPCs would do it unaided - they
will not, and the binary says they cannot: combat locomotion neither consumes ORCA nor requests
paths from the pathfinder, and its own obstacle weights are baked rather than cvars. So the
fight is staged instead, both sides walked to the gaps before blows are struck. Wall COLLISION
is a separate layer that runs regardless (`mercenaries_solid.lua`): staging decides where they
walk, collision stops them walking through the timber. `merc_wb_enable 0` turns staging off.

`merc_wb_status` reports each man's nav state, which is what to read when only some of them
route properly:

| State | Meaning |
| --- | --- |
| `leg N/M` | routing round the wall, on leg N |
| `straight` | line to his slot is clear, no detour needed — walking straight is correct |
| `NO ROUTE` | A* found nothing; he beelines and will clip the wall |
| `queued` | order given, the tree has not started the move yet |

A `(wall in the way)` suffix means a wall stands between him and his slot right now, so
`straight` paired with that suffix is the case worth investigating.
