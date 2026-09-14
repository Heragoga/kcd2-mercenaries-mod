# What counts as "the ground"

Every placement in the mod ends in a downward raycast: camp props, stations, patrol
waypoints, a teleported straggler, an ambush, a bandit camp. Until now the answer was always
the **first surface the ray met**. On open terrain that surface *is* the ground. Over a house
it is the roof, on a log it is the log, over one of our own tents it is the tent — and the
prop or the man was put on top of whatever happened to be in the way.

That is both halves of the report this module exists for:

* *"stuff spawns on other objects in the game world"*
* *"patrolling mercs get teleported to the roofs of buildings"*

`data/Scripts/mods/mercenaries_ground.lua` is the one place that tells those cases apart.

## What the probe actually reported

Two versions of this module shipped saying "firm ground" to everything, including a player
standing on a woodpile. Both were guesses. This is the log line that settled it, from
`merc_groundprobe` standing on the pile:

```
terrain: GetTerrainElevation nil vs ent_terrain ray 56.26
1 surface(s) in the column, probe mask 263
1. z=   57.86   [dist=48.3956 renderNode=userdata: 0000023B4C9C7A00 surface=138]
```

Four facts, all of which matter:

1. **`System.GetTerrainElevation` returns `nil`.** Every call, everywhere. That is the whole
   bug: the check that was supposed to catch a surface standing proud of the ground had
   nothing to compare against, and `if not terrainZ then return true end` passed it.
2. **A ray restricted to `ent_terrain` works perfectly** — 56.25, 56.26, 56.28, 56.44 across
   the samples. That is the real ground height, and it is what the module uses now.
3. **`surface` discriminates.** The terrain reads `surface=1`; the woodpile on top of it
   reads `surface=138`. This is the signal the guard is built on. `System.GetSurfaceTypeNameById`
   is live (it is in the Lua state dump), so `merc_groundprobe` prints the names too.
4. **`renderNode` does not.** It is set on the *terrain* hit too, so the
   `entity`/`renderNode` classification that v1 was built on separates nothing in this build.
   The `hit kind: WORKING` line in the old probe output was itself misleading.

A fifth, which shapes the design: the ray returns **one hit however many are asked for**. It
does not pierce, so walking down a column is not available — which is why the terrain ray is
also what supplies the ground height *underneath* an obstruction.

A height comparison would have caught this particular pile — it stood 1.60 m proud — but not
a straw mat, a cloth or a sack, and no threshold catches those without throwing out every path
and kerb in the game. Hence the material rule below.

## The test is what the surface is made of, not how high it is

### 1. The terrain ray — the test

One ray with `iEntTypes = ent_terrain`. Whatever it hits is the heightmap by construction, so
it reports both **how high the ground is at this exact column** and **what the ground is made
of**. Anything lying on top of it is made of something else.

**The rule carries no height term.** Height was tried and cannot work: a straw mat is two
centimetres thick, a cloth or a sack less, and any threshold low enough to catch them throws
out every path and kerb in the game. There is no height that separates "a thing lying on the
ground" from "the ground". A straw mat reads as straw at 2 cm just as loudly as the woodpile
reads at 1.60 m.

```
surface ~= the ground's surface  ->  an object, at any height
```

Height survives only as a backstop for the one case material cannot see — something made of
what the ground is made of, standing proud of it, like a stone block on stony ground:

| | |
|---|---|
| `GroundSameRise` | 0.80 m — same surface type, but perched this high |
| `GroundBelowDrop` | 2.0 m — below the terrain is a pit or a cellar |

When the top surface fails, `GroundUnder` returns the **terrain height** as the ground rather
than the top of the obstruction, so a prop over a woodpile lands at its foot.

### 2. The edge test — for columns with no terrain in them

Ring a point with probes; if every side drops away, it is the top of something. Needs nothing
but rays, and covers the one case the terrain ray cannot answer: a column with no heightmap
under it at all — a bridge deck, an interior where the terrain is cut away.

What keeps it off good ground is the shape of the rule, not the threshold: on a **hillside at
most half the ring drops**, because one side is uphill. That is why the cheap 4-probe version
demands all four. A crest drops on two.

| | |
|---|---|
| `GroundEdgeRadius` | 1.25 m |
| `GroundEdgeDrop` | 0.25 m |
| `GroundEdgeFast` | 4 probes, all must drop |
| `GroundEdgeRays` / `GroundEdgeMin` | 8 / 6 — the full ring, for `merc_groundprobe` |

### The raycast mask

Every probe in the mod asked for `ent_terrain + ent_static`. From the live Lua state dump in
`references/kcd2-mod-docs-main/lua_dump_state`: `ent_static`=1, `ent_sleeping_rigid`=2,
`ent_rigid`=4, `ent_living`=8, `ent_independent`=16, `ent_terrain`=256, `ent_all`=287. So the
mask was **257** and could not see a rigid body — a cart, a barrel, a corpse. That was *not*
the cause of these reports (the woodpile is static geometry and came back either way), but it
is wrong all the same, and `GroundMask()` is now **263**. `ent_living` stays out: a merc
standing in the way must not condemn the ground he is on. `CampDetectRoof` stays at 257 — it
asks whether there is *shelter* overhead, and a parked cart is not a roof.

With the guard off, `GroundMask()` returns the old 257, so the toggle restores the previous
behaviour exactly.

## Where it is wired in

| Where | What it does | Cost |
|---|---|---|
| `CampValidateSpot` | terrain-ray test on the centre, then the edge test last, after everything cheaper has had its chance to reject | +1 ray, +4 more on a spot that passes all else |
| `FindValidGround` | spirals with `skipEdge`, then runs the edge test **once on the winner** and carries on spiralling if it fails | +4 rays per *search*, not per candidate |
| `CampSnapToGround(pos, verify)` | returns the ground, not the top of what stands on it; `verify` adds the edge ring, and only where the terrain ray had nothing to say | +1, or +5 |
| `SpawnCampPropModel` | snaps with `verify` | +1 per prop |
| `ForgeFindFlattest` | forge, inn, alchemy bench, food cart, hunting stand — flatness alone scored roofs and cart beds as perfectly level | +1 per candidate |
| Camp heightmap sampler | terrain sub-grid at 2 m marks cells made of something the ground there is not; skipped entirely with the guard off | +7% rays |
| `GetSafeSpawnPosition` | walks back along its bearing to open ground; its old snap started 5 m above the player's own height, and a one-storey roof sits inside that | ~4 rays |
| Camp guard patrol ring | validated and dropped where blocked; one ring for the whole camp, not one per guard | — |
| Straggler teleport | skips a tick rather than dropping a man under a house | — |

### The camp map, and why the terrain grid is coarse

The map is the camp spawner's own picture of the ground: one ray per 0.5 m cell over the
whole camp footprint, flood-filled from the player's feet into `valid` / `small` / `building`
/ `void`. Tile selection, the player-tent search and every prop nudge read it.

Testing each cell's material needs a *second* ray, and the fine grid is already ~8,000 of
them at full camp radius. So the terrain is sampled on **its own 2 m grid** — terrain layers
are large patches and their material does not change every half metre:

| map radius | fine grid | terrain sub-grid | added |
|---|---|---|---|
| 8 m | 33×33 = 1,089 | 9×9 = 81 | +7.4% |
| 14 m | 57×57 = 3,249 | 15×15 = 225 | +6.9% |
| 22 m | 89×89 = 7,921 | 23×23 = 529 | +6.7% |

A fine cell is compared against the **four terrain samples around it** and counts as ground
if it matches **any** of them. That is what makes the coarse grid safe: on a grass/dirt
boundary a single nearest sample would often be the wrong layer and punch holes in the map,
while "matches one of the materials hereabouts" does not care which side of the boundary the
sample fell on.

Cells that fail are marked unwalkable but are deliberately kept **out** of `hasZ`, so they
still go through clump sizing: a straw mat comes out `small` (tolerable — props step round
it) where a woodpile or a cart comes out `building`. Folding them into `hasZ` would make
every mat a hard barrier.

The consequences follow for free, because everything already reads this map: a camp ordered
while standing on a woodpile relocates to the nearest real ground (`CampNearestValidCell`),
tiles whose footprint is mostly matting are rejected, and the player tent's search avoids
them.

`merc_camp_scan` shows it — flag = valid, barrel = small clump, crate = building — and its
summary now says how many cells the guard took out on its own, so a gap in the flags can be
told apart from one the classifier's step test made. Every camp pitch also logs one line:

```
[Mercenaries] camp map 22m: 6142 buildable, 318 tree/rock, 1203 building, 258 void (ground guard on)
```

## When the guard is wrong

The rule is that a surface standing proud of the terrain is not the ground. That holds
wherever people walk on the heightmap. Somewhere built on static meshes standing clear of it,
the guard would rule out ground that is perfectly good.

`GroundSelfCheck` runs once a second from the monitor loop, skipped while mounted, under a
roof, or standing still — a man who parks himself on a woodpile must not be able to disarm the
guard by waiting. The player is on real ground by definition, so the guard's verdict on his own
column has a right answer already. The bar is set high on purpose: about **200 m of walking
with four fifths of it reading "on an object"** disables the guard entirely and says so, since
that is a region where the rule does not hold rather than a stroll past some crates.
`merc_groundguard 1` puts it back.

`CampBuildMap` has a second failsafe: a camp map with not one buildable cell is rebuilt with
the guard off, and if that changes the answer the guard was the reason and is turned off.

## Diagnostics

| Command | What it does |
|---|---|
| `merc_groundprobe` | The instrument, and what settled this. Under you and under the spot you are looking at: the terrain ray's height and surface, what `GetTerrainElevation` says, **every key the engine actually put in the hit**, the rise above terrain, the edge test's drop count, and the verdict |
| `merc_groundscan [radius]` | Count open-ground vs blocked columns around you, edge test included |
| `merc_groundguard 0\|1` | Turn the guard off or back on, live |

All three need `merc_dev` first.

The raw key dump is there because that is the only way to find out what this build reports —
the camping mod (`references/zdjbcamping_mod`) tried the same `for k, v in pairs(hit)` and its
call was malformed (no hit table argument, then `#hits` on an integer), so it never ran.

## Reading the bind

From `sub_39AA4B0` in `WHGame.dll` (`release_1_5_1308617_856`), the per-hit tail of
`Physics.RayWorldIntersection`:

```
set "pos", "normal", "dist", "surface"
pCollider->GetForeignData(2)        ; PHYS_FOREIGN_ID_ENTITY
  non-null -> set "entity", done
else GetiForeignData()
  == 1 (STATIC)  -> GetForeignData(1)          -> set "renderNode"
  == 3 (FOLIAGE) -> GetForeignData(3)->vf(0x30) -> set "renderNode"
  otherwise      -> set nothing                 ; terrain is foreign id 0
```

So the theory reads well and the practice does not: in this build `renderNode` comes back set
on the terrain hit too. `surface` is the field that earns its keep — always set, and different
for the ground and for what stands on it (1 vs 138 in the probe above).
`System.GetSurfaceTypeIdByName` is a live bind, so surface **names** could be resolved to ids
if a sharper rule than "different from the ground's" is ever wanted.
`System.RayWorldIntersection` is a *different*, thinner bind (`sub_39AA8A4`) that sets only
`normal`, `dist` and `surface` — do not use it for this.

## What the camping mod does

Nothing like this. `references/zdjbcamping_mod` casts one ray down from +50 m
(`GetTerrainPosFromVec` / `GetTerrainNormalFromVec`), takes the first hit, and uses its
position and normal to **align** a prop to the slope. Its only placement gate is
`IsSuitableLocation`, which is `System.GetEntitiesInSphere` over a radius and a check that
nothing but the player, a torch, a light, audio or a pickable item is inside it. It has no
roof, object or ground test at all — it simply refuses to camp near anything.

That last idea is worth keeping in mind as a cheap complement: it catches things by their
*entity registration* rather than their geometry, which is the one class of object the edge
test can miss (something wide and flat with no visible rim).
