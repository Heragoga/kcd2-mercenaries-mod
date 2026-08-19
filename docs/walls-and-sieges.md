# Walls, pathfinding and staged battles

Three systems, in the order a fight uses them.

| File | Job |
| --- | --- |
| `mercenaries_wall.lua` | building the palisade (barrel markers -> tiled wall segments) |
| `mercenaries_navmesh.lua` | a custom grid + A* so mod NPCs route around the wall |
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

## Why a custom navmesh

The wall is spawned at runtime, so the engine navmesh knows nothing about it. Everything
that would normally stop an NPC walking through was tried and ruled out:

- `AI.SetPFBlockerRadius`, `AI.CreateTempGenericShapeBox` — no effect on spawned walls
- all 24 `g_PhysicsCollisionClass` classes — none block AI pathing
- the `sa_deterrentArea` prefab — the area instantiates but its `TagPoint` will not spawn,
  and it is gated on `global_deterrentAreasActive`
- NPC-vs-NPC body blocking — NPCs push through each other

So `NavIsBlocked(a, b)` is a plain 2D segment-intersection test against the wall corner
list, and `NavPathAround` runs A* over a grid whose edges are cut where they cross a wall,
then string-pulls the result. It applies only near a camp (`NavActiveRadius`, 60 m) and
only to mod NPCs.

`NavSteerPoint` is the shared core — `nav_goto.xml`, the merc slot hook and camp patrol
all call it rather than duplicating the logic.

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

- **contact** — any attacker within `WBEngageDist` of any defender. Since that distance is
  about the width of no-man's-land between the two lines, the first man to reach the gap
  starts it; everyone still short of their slot is released and walks in under their own
  behaviour, like any other fight
- both lines formed (per-side quorum) plus `WBStageGrace`
- the staging allowance expiring

The quartermaster is a defender. He is not in `ActiveMercs`, so before that he was the one
man with no muster point and no combat lock, and charged through the wall alone.

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

### Scheduled raids (`mercenaries_raids.lua`)

`RaidTick` fires a raid roughly every `RaidDaysBetween` days (2, ± `RaidDayJitter` so it is
not clockwork), and only when:

- the camp is pitched **and the player is standing in it** (`RaidCampRange`, 45 m) — a raid
  nobody is there to fight is just a band of men standing in a field
- no fight is already under way (`WBPhase` is idle and no raid force is still alive)

The force is `RaidShare` (80%) of the living company, clamped to `RaidMinCount`..`RaidMaxCount`,
so it is a real fight without taking away the edge the wall and the archers are meant to give.
Its quality follows the company's own: the mean of the men's tiers picks the enemy group
through `RaidGroupByTier`, reusing the mapping the old renegade tiers used
(weak → looters, medium → bandits, strong → knights).

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
| `merc_nav_build [radius] [spacing]` | rebuild the graph |
| `merc_nav_show` / `merc_nav_test` / `merc_nav_clear` | visualise and test routes |
| `merc_wp_radius <switchM> <arriveM>` | corner smoothing |
| `merc_nav_lane <metres>` | lane spread off the shared route; 0 for single file |
| `merc_nav_aim <metres>` | how far ahead the steering point is held; 0 brings the halting back |
| `merc_nav_debug 0\|1` | nav logging on the hot path |

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
