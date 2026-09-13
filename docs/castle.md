# Castle builder

Stone walls, corner towers and a choice of gate. `merc_castle_build` starts it.

It is **not** a second builder. It selects a stone wall type, arms the corner towers and
the back-face doubling, then hands over to the ordinary wall build mode, so:

- runs land in `WallRuns` like any other, and the navmesh, the staged battle, the raid
  checks, the gate sentries and the defence save all keep working
- `merc_wall_undo`, `merc_wall_undo_run`, `merc_wall_close`, `merc_wall_clear`,
  `merc_wall_rebuild` are the same commands they always were
- the wall types are **appended** to `WallTypes`, never inserted, so `QMWallType` in an
  existing save still means what it meant

Drawing works exactly like the palisade: left-click marks a corner, right-click finishes,
and a click within `merc_wall_gatesnap` metres of the **free end** of an existing wall
hangs the **gate** and ends the stretch.

The free end matters. A gate is hung by carrying the wall's own line onward — it starts at
the end and grows outward from it, tucking back by `GateWallDist` (-0.60 m) so the joint
has no daylight — and there is nowhere else on a run that can happen. The snap used to take
the nearest *segment* and grow the gate out of whichever end of it was closer to the aim,
so aiming anywhere along a stretch threw the gate to that stretch's far corner, and aiming
at a corner put it 1.4 m past, on top of the wall that follows. A 45-degree turn hid it
(the two lines diverge fast); a freehand palisade bends gently, so it landed squarely on
the next stretch — **one anchor point along**. Only free ends are offered now: a click in
the middle of a wall marks a corner, as it should, and a closed ring offers nothing.
`tools/check_wall_gatesnap.py` holds it.

## The four things stone needed

### 1. A choice of segment

**`kh_a` is the default** — `merc_castle_build` selects it without being asked. It is the
only base-game curtain that is intact, tiles on a pitch it was designed for, carries a
wall-walk, and owns a corner for both hands, so `merc_castle_square` closes on itself.

`merc_castle_wall <n>` picks from 60, in seven groups:

| Group | N | What it is |
| --- | --- | --- |
| `custom` | 5 | **Ours.** Crenellated castle walls built in Blender and compiled with the modding tools' `rc.exe`, textured with the base game's own stone — see [custom-assets.md](custom-assets.md) |
| `kh` | 17 | **The Kuttenberg walltool kit** — the level designers' own modular city wall, and the best base-game answer to "a wall you can defend". See below |
| `castle` | 10 | The nine standing ruined fortress pieces plus `whitewash`. The only individual castle-height stone walls that are *ruins*; every intact castle wall exists solely as baked fortress geometry |
| `rubble` | 11 | Same family, but not curtains: the `piece_d` set is a 1.5 m foundation lying flat, `g`/`j`/`l` are corner-and-tower chunks 12–15 m deep, `beam_a`/`b` are loose timbers, and `suchdol_dmg` is 26 m of palace. Scatter, never a wall |
| `low` | 8 | `wall_low_ruined_kh_*` — low ruined town walls, knee to waist (0.70–0.98 m), light and dark |
| `fence` | 6 | `stone_fence_5m*` / `_16m*`. Free-standing field walls, modelled on both sides. `_noterrain` drops the strip of baked ground at the foot; `_cropped` shaves the top off |
| `seg` | 3 | `wall_segment_220_60_a_*` — despite the name, 5.05 m long and 2.30 m tall, with its origin at one end |

#### Every mesh here is one object, and that is the whole point

Most of what reads like a castle wall in this game is **one baked level section**, and
spawning it as a wall segment tiles whole castles on top of each other:

| mesh | nodes | what comes with it |
| --- | --- | --- |
| `walls_semin.cgf` | 205 | the settlement |
| `malesov_wall_tower.cgf` | 168 | the tower and its castle |
| `gate_kh_01.cgf` | 187 | the whole Kutná Hora gate complex |
| `malesov_wall_01.cgf` | 91 | `allure`, `fortress`, `round_tower`, `stairs`, `wall_01/02/03`, **`wall_gate_part`**, `wall_tower` |
| `suchdol_fortress_walls.cgf` | 32 | arcades, bridge, gate, palace, two more wall runs, a tower |
| `stone_fence_5m_noterrain.cgf` | **1** | `stone`, `stone_top` |

That is where the gatehouse and broken gate came from: `malesov_wall_01` *is* the
Malešov fortress. A second trap sits behind it — some single-object walls (Cimburk's
ruins, the Opatovice parcel walls, the Trosky gatehouse, `castle_wall_test`, `gate_kh_02`)
are `physicalized_whitebox` blockout art with no texturing.

`tools/cgf_nodes.py` reads the CGF chunk tables straight out of the paks and reports both.
Run it before adding any mesh:

```
python tools/cgf_nodes.py --lua data/Scripts/mods/mercenaries_castle.lua --problems
python tools/cgf_nodes.py --single wall stone        # find new candidates
```

One node is one object; up to six is one object with its own parts (a gate, its leaves
and its decals); beyond that it is a slice of a level.

### Seeing them tiled

`merc_castle_matrix <group>` lays a group out as short tiled runs — each candidate at its
own length, with its corner tower — one row per candidate, rows 9 m apart going away from
you. A run of four shows what a single mesh in a gallery cannot: whether it repeats,
whether it meets its neighbour, whether the tower matches its height.

The group is optional and a bare number still works as the run length, so
`merc_castle_matrix castle`, `merc_castle_matrix all 20 12` and `merc_castle_matrix 20`
all do what they look like. Each row logs the segment's **own** index, so
`merc_castle_wall <that number>` picks it even when the lineup was filtered.
`merc_castle_matrix_clear` removes it.

### Seeing them enclose something

A run answers "does this tile". It does not answer the question that actually picks a
wall type: what it looks like turning a corner, and what the **inside** face looks like,
which on a one-sided mesh is the half nobody checks until the camp is standing in it.

`merc_castle_rects` builds a closed rectangle out of each candidate and lays them out in
a field you can walk between, one tile left out of the near edge of each as a doorway.
With no argument it builds the curated dozen in `CastleRectPicks`; `merc_castle_rects
castle`, `merc_castle_rects all 32 16` and `merc_castle_rects picks 40` also work, the
two numbers being the target side and the gap between rectangles. Each side is rounded
to a whole number of that piece's own tiles, so the rectangles come out different sizes
and no seam appears that the real builder would not also make. Cleared by
`merc_castle_matrix_clear` along with the lineup.

The dozen is the **Kuttenberg walltool kit**, `objects/intermediates/walltool/`. It is
the level designers' own modular city wall, and it is a different class of thing from
everything else in the table: intact rather than ruined, tiling on a pitch it was
designed for, every piece one node and fully textured, and — unlike anything else in the
game — carrying a real **wall-walk**. `wall_kh_a` has 24 m² of deck at 8.00 m.

| | tile | stands | walk | note |
|---|---|---|---|---|
| `kh_a` | 12.39 m | **7.20 m** | **5.00 m** | the city wall proper, 2.5 m thick, sunk 3 m by default |
| `kh_b` | 12.30 m | 10.14 m | 8.00 m | |
| `kh_c` | 12.27 m | 10.10 m | 8.00 m | |
| `kh_d` | 12.21 m | 10.09 m | 8.00 m | |
| `kh_e` | 12.29 m | 10.20 m | 8.00 m | |
| `kh_a_wet` | 12.22 m | 10.20 m | 8.00 m | the weathered colourway — `_wet` exists for all five |
| `kh02_a` | 9.99 m | 8.26 m | 6.00 m | the thinner second wall |
| `kh02_b` | 9.99 m | 8.18 m | 5.90 m | |
| `khstone_a` | 4.31 m | 3.58 m | — | the town's yard wall, 0.7 m thick. Not defensible, and it reads as one |
| `khstone_b` | 4.31 m | 3.62 m | — | |
| `khplaster_a` | 4.31 m | 3.58 m | — | the same wall plastered |
| `khplaster_b` | 4.31 m | 3.62 m | — | |

Two things about this kit that nothing else in the table needs:

* **It runs along the mesh's own +Y**, not +X, so every entry carries `yaw = -90`. Without
  it each piece stands across its run instead of along it. `WallSelect` pushes it into
  `WallYawFix` the same way it pushes `up`, `lat` and `ox`.
* **Every piece is modelled from one end** rather than about its middle, so `ox` is half a
  tile (6.23 m on `kh_a`) rather than the couple of centimetres the other families need.
* **The two city walls carry `up = -3.00`.** 10.2 m is right for a city and too much for a
  camp, so they are sunk three metres into their own foundation: 7.2 m stands, the walk
  lands at 5.00 m, and 1.9 m of the mesh's 4.9 m footing is still below ground. It also
  puts the walk level with `bastion_kh_01`'s lowest platform. `merc_wall_up 0` undoes it.
* **Towers stand off the turns by default** (`towerEvery = 0`). A type owning a corner for
  both hands closes every turn itself; leaving the usual one-every-other-corner drops a
  tower — and it was still the old Blender one, at a different height — onto half of them,
  which reads exactly like the corner piece failing to appear.
* **Gate snapping is off for every castle type.** Stone is drawn corner to corner, and a
  click landing near an existing wall should mark a corner, not silently become a gate.
  The palisade keeps it.
* **Only stone snaps, and only to the turns its own kit has.** The snap angle comes from
  the type's corner list (`CastleSnapAngleFor` takes the gcd of the turns it owns): the
  Kuttenberg walls carry 15/30/45/60/75/90 and so snap to 15. Letting the player draw a
  turn there is no mesh for is what a wedge of daylight at a corner looks like.

  **The palisade is freehand** (`WallSnapAngleDefault = 0`). A 2.75 m stake panel meets
  its neighbour at any angle you like and a corner post covers the joint, so there is
  nothing for a snap to protect there and it only stops you drawing the line you want. A
  type earns its snapping by owning corner pieces; everything else is drawn by hand.
  `merc_wall_angle` still overrides either way, and `tools/check_wall_freehand.py` holds
  the line: a palisade aimed at 7 or 73.3 degrees keeps it exactly, and still tiles with
  no stacking and zero spacing error.

Its `_left_90` and `_right_90` corners **are** wired up (see below) — it is the only
family in the game with a corner mesh for both hands, so it is the only one whose right
turns do not fall back to a tower. Its `_end_a`, `_start`, `_gate_a/b/c`, `_doorway` and
`_up`/`_down` slope pieces are not fitted yet, and the town's yard wall is a different
cross-section whose corners are not fitted either — those three rectangles butt.

`merc_castle_rects castle` still builds the ruined fortress pieces if you want to compare:
`ruin_k` is 9.19 m and stands 12.13 m, the tallest curtain the game has.

### Slopes

A wall type that owns transition pieces **walks** the ground instead of being levelled.
The pitch, the cuts and the corners are untouched — only which mesh goes in a slot.

The city wall **enters** a lean, **holds** it while the ground keeps pulling away, and
**leaves** it back to level, so a long climb is one continuous 12° incline rather than a
staircase. The three pieces chain because their end faces agree on the angle: `enter` runs
0°→12°, `hold` 12°→12°, `leave` 12°→0°, and a level straight is 0°. Each carries its own
rise (1.01 / 2.62 / 1.06 m) because they are not the same length of lean.

Two rules make it behave. A hold is spent only when **a whole tile of lean is warranted** —
a 12° lean climbs 2.6 m per tile against ground that typically rises one, so testing merely
"is the ground still above us" spends holds that overshoot and then have to be levelled off
again. And a lean must be **left before the edge ends**, or the run finishes on a tilted
face with a level corner to meet. On ground at the lean's own 21% gradient it walks the
whole run in a single lean; on gentler ground it alternates short leans with level tiles:

```
 5% climb   ..IO.IO..IO.       I enter   H hold   O leave   . level
 8% climb   ..IHO.IOIOIO
15% climb   .IHHOIHHOIHO
21% climb   .IHHHHHHHHHO       one continuous incline
```

The tilted faces overhang their tile — the top of a leaning wall leans past its own
footprint — but the next piece leans the same way, so they interlock rather than collide
and the spacing along the ground is still one tile.

The city wall's are **generated** — the same mesh deformed, see below. Only the **yard
wall** ships them. `stone_wall_kh_up` lifts the crest 1.402 m across one
4.37 m tile and `_down` drops it 1.373 m, which caps the gradient the wall can follow at
**32%**; past that it falls behind and no amount of cleverness helps, because the game
ships no steeper piece. The city wall has none — there is no `wall_kh_up` in the paks — so
it keeps the levelling rule, which has 7.9 m of buried footing to absorb a fall before any
daylight shows under it.

`tools/check_wall_slope.py` walks both yard walls up and down seven height fields and
checks the crest never strays more than one and a half steps from the ground (a step fires
at the half-step mark, so it can lag that far either side), that flat ground places no
transitions at all, and that a valley turns the steps round rather than running one way.

### Generating the pieces the kit does not ship

`assets/gen_wall_pieces.py` reads a mesh out of the pak, moves its vertices and writes it
back for Blender and rc.exe. Three things it learned the hard way:

* **Build a slope from the GRADIENT, not from a curve.** A smooth S from end to end is
  wavy because nowhere on it is the wall straight. The gradient is piecewise *constant* —
  level, or one fixed lean — joined by short fillets, and the height is its integral.
  Everything between the fillets is straight wall, which is 79–100% of each tile.
* **The battlements stay level.** A wall climbing a hill leans; its merlons do not, they
  sit level and step down. So above the walk the shear is quantised to the merlon pitch
  (3.10 m), below it the masonry leans continuously, and the two blend across the coping —
  which is exactly where a real wall takes up the step.
* **Carry the vertex colours, or it is not the same wall.** Every submaterial on
  `wall_kh_beige` declares `%VERTCOLORS` and most `%BLENDLAYER`, which reads the vertex
  **alpha** to choose between its two stone textures. OBJ carries no vertex colour at all,
  so the first attempt dropped the lot and the pieces came out visibly different from the
  wall they were cut from. The mesh now goes to Blender as a raw array dump instead. Two
  traps behind that one: do not swap the channel order on the way in (the reader hands
  them over BGRA and reads them back the same way), and export `colors_type="LINEAR"` —
  these bytes are blend data, not a colour to display, and a gamma curve shifts every
  blend in the wall.

Also: **rc.exe returns before its output is on disk.** Patch the material library straight
after it and the late write lands on top, putting the name back to `default` — which costs
the piece its collision and says nothing at all. `assets/build_wall_pieces.ps1` waits for
each file to stop changing, and reads the library back before installing.

### An exact rectangle

`merc_castle_square [tiles] [tiles across]` lays one from the grid: each side is the corner
allowance plus a whole number of tiles, which is the only length that tiles cleanly.
Drawing one by hand cannot come out exact, and not because the snapping is weak — the first
edge is marked before a corner exists at its start, and the closing edge is never marked at
all. Those two get whatever the shape leaves them.

Two things had to change for this to hold. Edges now snap to `allowance + n*tiles` rather
than `n*tiles`: the corner pieces are not a whole number of tiles wide, so the old grid left
a remainder the tiling could not use and the flush fill covered it with a piece laid nearly
on top of its neighbour — a 9 m overlap on every edge. And **a closed ring is no longer
refitted**: the refit walks corners in order and each correction moves the one after it, so
a ring comes out a different shape than it went in, and its closing edge is never fitted
because there is no corner after the last one to fit it against.

`tools/check_wall_square.py` builds 0/2/3/4/6-tile squares of three wall types and checks
all four sides match, each is a whole number of tiles, exactly `4n` pieces are placed (one
more means the flush fill fired), and the placed meshes meet with no daylight.

### Measuring a piece instead of guessing it

Every `len` in the table used to be a guess outside `fence` and `seg`, and they were
wrong — `low_a` was declared 4.00 m and tiles at 3.12, so every piece of it left a 0.88 m
hole. `tools/measure_walls.py` reads the meshes out of the paks and prints the four
figures a row needs. They are all now measured:

* **`len`** is the tile pitch, floored to a centimetre so a pitch is never longer than the
  stone. **Measure it on the wall body, not on the mesh's outer extent.** Neither extreme
  is the pitch: the bounding box takes in the parapet overhang, which juts 1.5 cm past the
  body at each end *precisely so it laps the neighbour*, and tiling on that opens a 2 cm
  gap down the whole wall face. The percentile trims the wrong end instead and shortened
  `kh_a` by 18 cm. What works is the commonest span across half-metre height bands — the
  body's own width repeats up the full height, while the overhang is two bands out of
  thirty and cannot outvote it. All ten city-wall variants then agree on 12.39 m, which is
  what a modular kit should produce.
* **`ox`** is where the body sits **along** the run relative to the origin. `seg220` and
  `whitewash` are modelled from one end outward, so without it the whole wall slides half
  a tile off its markers. `WallEdgeSegments` subtracts it at placement.
* **`lat`** is the same across the run: what `WallLat` has to be to put the body on the
  line, measured inside the same body band. The overhang is wider than the wall under it,
  and letting it vote shoves the thin `kh02` wall 0.72 m off its own line.
* **`tall`** is the height **above** the origin. These meshes bury 1.5–4.3 m of
  foundation, so a bounding box is half again what you can actually stand behind.

`tools/check_castle_rects.py` runs the real `CastleRects` in LuaJIT and then checks the
result against the meshes themselves — it pulls each piece's true span back out of the
pak, puts it where the builder put the entity, and fails if neighbouring stones do not
meet. That is the check that catches a wrong `ox`, which leaves the tile centres perfect
while the stone sits half a tile down the run.

### 2. Corners

Two straight segments meeting at an angle leave a wedge open on the **outer** face — the
wider the turn, the wider the wedge. `merc_castle_corner_45/90/135` are the real answer:
one continuous mitred strip of the same cross-section bent through the turn, with a
quoined arris up the outside. They are single strips rather than two closed arms meeting,
because arms leave their own inner kerbs standing across the walking route.

**Every piece standing on a corner declares a `cut`, and that figure is taken off *each*
adjoining edge** — 2.00 m for the 45° and 90° corners, 3.00 m for the 135° (which needs
the extra room to get round), 4.00 m for a tower, which is 8.24 m across. Each is a whole
number of 4.00 m tiles or a clean half of one, so what is left of each edge still tiles
and the 1.00 m merlon grid carries straight through the turn. `CastleVertexPlan` decides
what stands there and `WallEdgeSegments` is handed the same figure (`span = L - cutA -
cutB`), so a piece never lands on a corner the walls have not stepped back from.

The mesh **is** the turn, and it is cut for a **left** one: the battlements are on the
right of the direction of travel, so an enclosure is walked anticlockwise. A ring drawn
the other way round has its battlements facing its own courtyard, and `CastleFixWinding`
silently walks it back the other way at the next rebuild. A right turn — the notch of a
re-entrant corner — has its outer faces on the *inside* of the bend where the two runs
already overlap, so it needs no piece; it takes a tower instead.

Only our own segments and the Kuttenberg kit have corners cut for them. A base-game wall
of a guessed length has no known tile and no merlon grid to continue, so its turns are
closed by a tower as they always were.

#### The walltool corners, and what they needed that ours did not

`CastleCornersKH` holds the kit's own pair, and a wall type may now carry its own corner
list instead of the shared one — `corners` is either `true` (use `CastleCorners`) or a
table. Three things about them broke assumptions the old corner code was built on:

* **Both hands exist.** `turnAt` has always returned a *signed* turn, positive to the
  left, and `CastleCornerFor` matches it against each piece's own `turn` — so a
  `turn = -90` entry is all a right-hand mesh needs. Our own corners are left-only, which
  is why a re-entrant corner has always taken a tower.
* **The turn happens inside the mesh, not at its origin.** `px`/`py` name that point and
  `CastleCornerOffset` shifts the piece so it stands on the marked corner. Without it the
  corner lands 5 m back down the incoming wall.
* **They are not symmetric about the turn.** `wall_kh_left_90` eats 5.09 m of the edge it
  receives and 3.89 m of the one it hands on; the right-hand piece eats 5.38 and 3.40.
  A single `cut` used both ways leaves over a metre of daylight on one side, so
  `WallVertexCut(r, i, side)` now answers `"in"` and `"out"` separately and the edge
  builder asks for the right one at each end. A spec with a plain `cut` still works.

`tools/check_castle_corners.py` drives the real builder — `CastleVertexPlan` picking the
piece, `WallEdgeSegments` tiling up to the cut it asks for — round squares of both hands
and a rotated one, then checks the placed meshes themselves for daylight on both arms.

### 3. Corner towers

#### What the base game actually has, measured

`tools/measure_walls.py` has a sibling question: which of the game's 103 tower-ish meshes
is a standalone prop rather than a slice of a castle, and which has a floor at the height
your wall walks at. For the Kuttenberg wall (walk at **8.00 m**) the answer is short:

| mesh | nodes | stands | footprint | decks | verdict |
|---|---|---|---|---|---|
| `bastion_kh_01` | 7 | 23.4 m | 8.6 × 8.9 | **5.0**, 11.8, 13.8 | the kh wall's **own** bastion, and the one to use |
| `monastery_tower_a` | 2 | 12.0 m | 4.9 × 4.9 | 5.5, **8.0**, 9.0 | slim turret, right height, wrong idiom |
| `husova_tower_b` | 1 | 23.1 m | 8.6 × 8.6 | 9.5, 12.3 | single-node KH town tower, decks too high |
| `ratibor_tower` | 2 | 11.5 m | 9.0 × 8.2 | 2.3 only | solid — no upper floor at all |
| `malesov_round_tower` | 2 | 11.8 m | 8.4 × 8.4 | 2.5, 5.3 | round, decks too low |
| `watchtower_a` | 2 | 9.3 m | 5.5 × 5.4 | 3.0, 6.0 | timber watchtower, not a curtain tower |
| `trosky_5_guardtower` | 2 | 13.1 m | 15.7 × 17.1 | 1.5–4.5 | footprint swallows the wall |
| `cimburk/ruined_tower_a` | 1 | 12.6 m | — | — | **whitebox**, no texturing |

`merc_castle_tower_row` stands **every** candidate up in a row with the curtain running
into it from both sides, which is the only way to see whether a tower reads as part of the
same wall or as a borrowed prop. Each one is sunk or raised so that whichever of its floors
is nearest the wall's own walk ends up level with it, the run stops on the tower's own
footprint so the two meet, and the log says what that cost — `HOISTED 5.8m` means the
tower's highest floor cannot reach the walk and it is standing on nothing.
`merc_castle_tower_row kh_a 3 10` names the wall, the tiles per side and the gap.

`bastion_kh_01` is the clear answer and it is genuinely self-contained — its seven nodes
are `bastion_walls`, `bastion_platform_01/02/03`, `bastion_stairs`, `bastion_roof` and a
shadow proxy, so it is enterable, it has stairs, and its lowest platform at 5.00 m is
exactly where the curtain's walk lands once that wall is sunk its three metres.

**Measure decks on the render mesh only.** A shadow proxy is upward-facing geometry like
any other and counting it invents floors that nothing can stand on — it is what put a
phantom 8 m platform on this bastion and a phantom 6 m deck on `watchtower_a`. Three more colourways ship: `bastion_kh_01_white`, `bastion_kh_03`, and
`bastion_kh_01_kourimska`, which is the Kouřimská gate version and drags a wall corridor
along with it. None of them is wired into `CastleTowers` yet.

The `lod2_*` textures these meshes name are missing from the paks, which is harmless — the
spawner forces `SetLodRatio(255)` so the LOD chain is never reached.

There is **no individual castle tower in the base game**. `watchtower_a` is 54 nodes,
`bastion_kh_01` is 127, `malesov_wall_tower` is 168 — each is a slice of its castle, not a
prop. So we built one: `crenel_a` (option 2, the default) is our own square corner tower —
a 7.60 m shaft (8.24 m over its footings and parapet), 11.2 m to the top of its merlons,
enterable, with a ground chamber, a clear first-floor hall at wall-walk height and an
**open** fighting platform above at 9.20 m. Three 1.70 m ports let the wall walk in and
out of the hall; the fourth face is a blind bay holding a continuous stairwell of 1.15 m
flights with return landings. The ground door is offset into the courtyard so it clears a
curtain joining the middle of that face.

It ships in two heights. `merc_castle_tower_a` sits its hall on the 4.90 m wall walk of
the standard kit; `merc_castle_tower_hand` puts it on the hand-built curtain's 6.00 m
walk, with the platform at 10.30 m and its ground door stepped out to 2.40 m. The builder
picks between them from the wall type's own `walkheight`, so there is no separate option
to set. Both are ~75k triangles with no LOD chain — see the note in
[castle-model-review.md](castle-model-review.md). See also
[custom-assets.md](custom-assets.md).

The base-game fallbacks are pillars: the fence family's own, the Sedlec monastery
buttresses, and the roadside devotional pillars. They read as a corner post, not a turret
— and `stone_fence_pillar` carries a baked grass and terrain skirt, so it plants a heap of
dirt at every corner.

`merc_castle_tower <n>` — 15 options, 1 being *none*. They stand every
`merc_castle_tower_every` corners (default 2, so every other turn; 1 for all of them, 0 for
none), and the corner pieces carry the rest. On an open run both ends get one too, which
`merc_castle_ends 0` disables. Towers are spawned into `WallSegEnts`, so they clear and
rebuild with the wall they belong to.

Three things place our own tower against our own wall, none of which apply to a base-game
segment or a pillar:

* **It is turned to the 90° lattice nearest both walls**, not to the angle bisector — a
  bisector stands a square tower on its diagonal at every right-angled corner.
* **It steps inboard onto the wall walk's centre line**, because that is where its ports
  are, so the walk runs in one side and out the other. The distance is the wall type's own
  measured `walkcenter` — 0.10 m for the standard kit, 0.35 m for the hand-built curtain,
  whose walking strip sits further back.
* **Its blind stair bay takes whichever of the four faces no wall arrives on.** The three
  remaining faces are ports, so any wall that meets the tower meets a doorway. The ground
  entrance follows the same turn and is offset into the courtyard; on a corner it ends up
  on the field side, and it is how the player first gets up onto their own wall.

### 3b. One height for a whole run

A stone wall cannot bend. `merc_wall_snap` puts each piece on the ground under its own
middle, which is right for a palisade of separate stakes and wrong for a 12 m block of
masonry: the run stair-steps and every joint tears open. `WallRunLevel` lays a **stone**
run at one height instead and lets the terrain swallow the difference. Castle wall types
only — `merc_wall_level 0` turns it off, and a palisade never had it.

Which height is the whole question, and it is decided from figures measured off the mesh:

1. Start at the ground under the **first** piece — where the player began drawing.
2. Keep it while that costs little: no piece buried more than a **third of its visible
   height** (`tall / 3`), and no piece left hanging.
3. Otherwise drop to the highest level at which **nothing floats**: the lowest ground on
   the run plus the foundation the mesh carries below its own origin (`deep`). These walls
   bury 2.5–4.9 m of footing, so that absorbs a lot of slope before daylight shows under
   one.

The float test is what makes rule 2 safe on its own: starting on a high mark would
otherwise hang the rest of the run in the air. The ground is sampled under the **middle**
of each piece, not under its origin — the walltool kit is modelled from one end, so the
two are half a tile apart and levelling off the origin drags the whole run down the slope.

The build-mode ghost is levelled the same way, over the marks already down plus the one
being aimed, so the joint you line up is the joint you get.

`tools/check_wall_level.py` runs the real `WallRunLevel` over height fields (flat, gentle,
3 m, 8 m, 20 m, a first mark on a peak, a valley, a ridge) for four wall types and asserts
the three things that must always hold: nothing ever floats, a flat run is left exactly
where it was drawn, and rule 2 only ever applies when burial is within the third.

### 4. Back faces — the see-through wall

The transparent sides came from the walltool pieces, which were **facades** — modelled to
be seen from one side, with a hollow back, so a run of them was see-through from inside.

Every mesh in the list now is a stand-alone prop rather than a slice of a building, so all
of them ship with `back = false` and cost one piece per segment. The machinery is still
there for the one that turns out hollow anyway: `merc_castle_back 1` doubles the current
segment — a second copy turned 180° and pushed along its own left by `CastleThick`
(default 0.60 m), so the wall presents a face each way and the gap becomes its thickness.
`merc_castle_thick` sets that distance; a negative value puts the copy on the other side,
which is what to try if the wall reads as thick on the wrong face.

## Gates

`merc_castle_gate <n>` picks from 6. They are appended to `GateStyles`, so hanging one
uses the ordinary gate machinery — E prompt, open/shut, sentries posted on it, raids called
off when every gate is shut.

`ratibor_gate` is the only stone gate in the game that is a single object. Every city gate
and gatehouse is its whole complex, and `gate_kh_02`, which *is* one object, is untextured
whitebox. The rest of the list is therefore the small multi-part gates — three to five
nodes, a gate with its own frame and decals rather than a slice of castle.

Most are **arches**: no open and shut variant was carved, so the style sets `frame` and
`GateModel` returns it for both states. The arch stands either way and only the colliders
and the pathing know the gate is closed. `nebakov` is the one with real leaves carved open
and shut, so it is the only one that visibly swings.

A stone gate is wider than a palisade one. Set `merc_gate_width` to match, and raise
`merc_wall_gatesnap` (default 3.5 m, tuned to palisade width) if the run will not snap onto
the wall it is reaching.

### A run is a chain of BEARINGS, not a chain of points

A corner is marked where the player aimed, but it cannot stay there: an edge has to be a
whole number of tiles plus whatever the pieces on its two ends take out of it, so the
mark is pulled back onto that grid. How far back depends on which bend its turn asks for
— and at the moment it is marked, its turn **does not exist yet**, because the corner
after it has not been placed. So the mark has to be moved again later, and that is where
two separate faults used to come from.

**It ratcheted.** The refit measured to the mark's current position and could only ever
shorten, so every rebuild pulled it in again: a corner shortened while it was still the
end of the run was shortened again from there the moment a turn appeared on it. A wall
drawn 25 m long came out 6 m long, one rebuild at a time.

**It swung.** A mark refitted towards a fixed world point drifts off the turn grid as its
own predecessor moves. `WallSnapAim` puts every edge on a multiple of 15°, but a mark
pulled in by 12 m leaves the next edge pointing somewhere else entirely — a turn of 40°
wearing a 45° bend, and a 5° wedge of daylight on the outgoing joint.

So a mark records the **bearing** it was drawn on and how far along it the player reached
(`bear` / `reach`, set in `WallMark`). The refit slides it along that bearing and nowhere
else. Bearings are fixed; only lengths are negotiable. Two things follow, and both are
checked by `tools/check_castle_corners.py`:

* every turn is exactly the angle it was drawn at, so the bend standing on it is cut for
  exactly that turn — 0.00° of error across every shape the checker draws
* the run can come back **out** again when its arm shrinks, because the bearing and reach
  it is measured against never move

Saved runs store only positions, so `DefLoad` recovers the bearings from the points
themselves — otherwise reloading and then changing the wall type walks the whole wall in.

### Fitting the arm: enumerate, don't iterate

Which arm a mark must step back for depends on the turn it makes, and the turn depends on
where the mark ends up. That circle does not close by chasing it — place, re-read, place
again simply swaps between two answers for ever, and each attempt measured from the last
one walks the run down to nothing.

`WallRefitChain` **enumerates** instead. Every arm the type owns is tried, at the furthest
fit and at one and two tiles short of it (giving up a tile can take a turn back below the
8° a corner exists for, which changes the arm again). Each candidate is scored on the cut
the run will **really** read there — not the one the candidate was built from, since some
turns have no arm that agrees with itself at all — and the widest candidate whose edge
comes out a whole number of tiles wins. A mark dropped for being too close restarts the
walk on the shortened chain, because the marks before the hole were fitted to a corner
that is no longer there.

Before this, 133 of 1600 drawable shapes laid a wall piece on top of another. Now none do.

### The flush fill, and when it must not fire

An edge with a remainder is covered by one more piece laid so its far edge lands on the
corner, overlapping whatever is already standing behind it. That is a fair trade while
something **is** standing behind it. When the remainder is a few centimetres the piece
reaches a whole tile back — straight through the corner mesh and out into the edge before
it. That is the duplicate wall a multi-turn run used to grow: a 12.39 m piece stuffed into
a 0.43 m gap.

`WallEdgeSegments` therefore takes `flush` as either `true` (a gate: the run **must** touch
`b`, whatever it costs) or `"cover"` (only while the piece's near end stops at or beyond
the corner's own turning point). With the refit above the remainder should always be zero;
the guard is what stops a stale figure from becoming a blob.

## The projection is a low stone fence

A 15 m curtain drawn between you and the ground you are aiming at hides the thing you are
aiming for. So the projection is a **low stone fence** on the same line: by default the 5 m
field wall, free-standing and modelled on both sides (no see-through ends to lid).
`merc_castle_ghost` lists the alternatives and swaps between them — two field walls, the
16 m one, the cropped pair and the two knee-high ruined town walls — because which one reads
best is a matter of looking at it. It follows the ground
rather than the run's laid height, because what it is for is showing you WHERE the wall
goes.

It still has to be honest about that: it starts at the corner being drawn from and ends
exactly where the last piece of wall will end, tiled at its own pitch and spread so it lands
on that end rather than overshooting it.

With `t.ghost` cleared the projection falls back to the wall itself, and then everything
below applies. Both paths are checked by `tools/check_wall_preview.py`.

## When the projection is the wall itself

Build mode previews the run from the last corner to the crosshair. It used to draw every
tile as the plain straight, which is a preview of a different wall — the joint you line up
is not the joint you get. `WallPreviewApply` now shows, for the live edge:

* the mesh the builder will actually lay for each tile — the sloped transition where the
  run climbs, not the straight
* the **bend that will stand on the corner being aimed**, so the turn is visible while it
  is being drawn rather than appearing on click
* a lid on each open end (below)

The pool is keyed by slot and a slot is respawned only when its mesh changes, since a
spawned entity's model cannot be swapped afterwards. `tools/check_wall_preview.py` drives
the real tick and compares it against `WallRebuild` piece for piece.

### The walls are shells, and the ghost showed it

`wall_kh_a.cgf` has **no geometry across either end face** — 59 m of open border and a
hundredth of a square metre of stone. Nor does any other piece in the kh family;
`wall_kh_end_a` is a short wall, not a closed one. In the levels the kit was cut for there
is always another piece against each end, so neither end was ever modelled. Backface
culling then makes a run's own ends see-through, which is invisible on a built wall (a
tower or the next piece stands there) and very visible on one being drawn.

`merc_kh_cap_start` / `merc_kh_cap_finish` close them. Each is the wall's own
cross-section, sliced 6 cm inside the end and scanned in 2 cm height bands for how wide
the stone is — exact for this profile (solid to the walk, then parapet only) without
having to triangulate the shell's many separate boundary loops, and taking each band's
outer extent means the lid can only be a hair proud of the stone, never a hair inside it
leaving a rim of daylight. Bands are run together where the outline holds, so a 15 m lid
is ~350 triangles. They carry the end's own vertex colours, because these submaterials run
`%VERTCOLORS` and `%BLENDLAYER` off the vertex alpha and a flat white lid would be a
different stone from the wall it closes. Ghost only — a built run ends on a tower.

## Closing the ring

A camp wants a wall the whole way round, and the way to ask for one is to bring the run
back to where it started. Within a tile and a half of the first corner the aim snaps onto
it and the next click CLOSES instead of marking (`merc_wall_close_snap` to change or turn
off). Walking a square round therefore closes itself on the fourth click, with nothing
extra to press.

Closing is **over-constrained**. Every edge has to be a whole number of tiles plus the arms
standing on its two ends, and the join also has to land exactly on the corner the run
started from; nothing satisfies both in general. Three separate things make it come out
anyway, and all three are needed:

1. **Refit the chain as a RING first, three times.** Closing turns the run's start into a
   turn: the corner it began at suddenly has arms, and the edges either side of it were
   fitted back when it had none. And the arms at the start depend on the turn there, which
   depends on where the LAST mark lands — a circle that runs the whole way round, so one
   forward walk fits the first edge against a last mark it has not placed yet. Each pass
   measures from the bearings the player drew, never from the pass before, so it settles
   rather than creeping.
2. **Search the last three marks for the join.** Each may slide to any length its own
   bearing and the tile grid allow, and the last may swing one snap step. A candidate is
   thrown out if it leaves any turn on an angle the kit has no piece for, or any edge off
   the tile grid — a wedge of daylight is worse than a seam. Once the join is within a few
   centimetres the one that drags the run least off what was drawn wins; without that the
   search happily shortens a 40 m side to 12 m for the sake of another centimetre.
3. **Share out whatever is left across the join's own joints.** `flush == "close"` spreads
   the pieces over the span instead of laying them exactly a tile apart, choosing between
   n and n+1 by which sits closer to the tile. A few centimetres at each of four joints is
   invisible; one 20 cm slot through a stone wall is not, and a whole piece laid on top of
   its neighbour is worse than either.
4. **Add a corner to the join when one edge cannot do it.** A single edge cannot be made
   to land on a corner it does not point at, however its length is chosen — one length is
   simply not enough freedom. `WallFitCloseCorner` gives the join **two** edges instead:
   each takes a bearing off the turn grid, where they cross is where a new corner goes,
   and the two lengths fall out of that intersection. Both marks before the join may also
   slide and swing a step. The corner reads as part of the wall because it is one, and it
   turns a 7 m seam into a 6 cm one.

   It has to earn its place. Dropping a corner in changes what the edges **either side**
   of the join step back for, so the search checks those two as it goes, and the finished
   ring is checked over by `WallRingFaults` — every turn cut for, no two arms through each
   other, every edge but the join's own halves exactly on the tile grid. If the ring comes
   out worse than it went in, the shape is put back as it was and the seam stands.

   The edge running **into** an added corner is allowed to spread as well (the mark carries
   `spread`), because after an insertion the join is two edges, not one. Without that the
   first half took the ordinary `"cover"` fill and laid a piece on top of its neighbour —
   which is the thing the whole exercise is meant to avoid.

5. **Give up the corner that is in the way.** The mark the player stopped on is not
   always one a ring can be closed from. Coming home nearly parallel to the first edge
   asks for a hairpin at *both* ends of the join — 130° and 175°, angles no piece in the
   kit is cut for — and the wall was then built with two corners simply missing, which is
   what a freehand ring mostly looked like. `WallCloseRing` therefore tries closing from
   the last mark, then from the one before it, then the one before that, and takes the
   first shape that comes out buildable. Losing a corner nobody will miss beats a ring
   with two holes in it.

A freehand square comes out exactly square — 46.15 m a side, every edge 3.000 tiles — and a
hexagon closes within 6 cm. The fit costs up to about a quarter of a second, once, on the
click that closes; it is deliberately not pruned, because pruning the search as it walks is
five times quicker and settles for a join a third worse.

**This is better, not solved.** Across 2400 freehand rings that actually come home, the
worst joint on the join is a median of **0.52 m**, down from 2.51 m, but **54% are still
worse than 0.35 m** and the tail reaches a whole missing tile. The shapes that fail are the
ones whose closing bearing cannot be put on the turn grid without moving marks further than
the search is allowed to. `merc_castle_square` remains the way to get a guaranteed-exact
enclosure; freehand closing is now usually good and sometimes visibly short of it.
`tools/check_wall_close.py` covers the cases that do work, so they cannot regress. `tools/check_wall_close.py` draws rings the way a player does
and checks the join, that no vertex the wall bends at is left bare, and that nothing is
laid on top of anything else.

One consequence worth knowing: a closed ring is **not** refitted by the ordinary pass
afterwards. It was fitted as a ring, and refitting it as an open chain slides the very
marks that were placed to bring the join home.

## The ring's closing edge

A ring's join has to land on its corner exactly, and a grid of fixed-length tiles cannot
cover an arbitrary span. Something has to give at that joint: either the pieces **part**
and leave daylight, or they **lap** and leave a seam.

The builder used to share the leftover out across the edge's own joints, on the reasoning
that a few centimetres at each of four joints is invisible. The flaw is that the spread can
only ever make the pitch **longer** than a tile — `n` is the floor of `span/step`, so
`span/n` is always at least `step` — and a pitch longer than the piece is a hole at every
joint. On a 50 m side it came to **1.14 m of clear air, three times over**: not a seam, a
way through the wall.

So the rule is now decided by what is left over:

| leftover | what happens |
|---|---|
| under a joint's worth of slack (~3 cm each) | shared across the edge's joints, as before |
| under 0.25 m | left against the corner, whose arm covers it |
| anything more | one more piece, pitch closed up so they **lap** |

A tile is modelled about 4 cm longer than the pitch it is laid at, and that over-length is
the only room a spread has — stretch past it and it stops being a joint. `WallJointSlack`
names it.

`check_wall_close.py` used to score gaps and laps with the same `abs()`, which made a hole
and a seam look like the same defect and let the daylight through. It now reports
`worst_gap_m` and `worst_lap_m` separately: **any gap over 0.15 m fails**, while a lap is
allowed up to a whole tile. Across four ring shapes the join is now 0.000 m of daylight on
three; the hexagon's join is a single tile that ends 0.138 m short against its corner.

## The gateway

A way through a stone wall is not a gate stood next to it, the way a palisade's is — the
wall has to open. The kit ships the answer: **`wall_kh_gate_a` is a TILE**, the same
12.39 m pitch as the plain curtain, with an archway cut through it. It drops straight into
the run in place of one piece, so the tiling does not change and the merlon grid carries on
over the top of it.

Two figures are read off the mesh rather than guessed: the archway is **2.60 m clear,
centred 8.75 m along the tile** from its origin, with 2.9 m of headroom.

**The kh curtain is no longer sunk, and the gatehouse is why.** It used to carry
`up = -3.00` — 10.2 m being right for a city and too much for a camp — but the archway is
cut at the mesh's own ground, so a wall dropped three metres into the earth cannot have one:
the opening ends up underground. Raising only the gate tile put its crown **5.87 m** proud
of the wall it was cut into, and compressing it to fit wrecks the stonework (the merlons and
the wall-walk both land at the wrong height). The wall stands at its full 10.2 m instead and
the tile drops straight in: the crown step is **0.13 m**, which is the difference between the
two meshes themselves.

The leaves are the game's `gate_d` pair — the only doors carved both open and shut that fit
a 2.6 m arch — hung through the ordinary gate machinery, so a gateway gets the E prompt,
the open/shut order, the raid suppression and the sentry posts that every other gate has. A
gate now carries its **own** style rather than the camp's current one, because a doorway cut
into a stone tile has its own opening and its own leaves.

**Its yaw is a quarter turn off the run**, exactly as a palisade gate's is. The leaves are
2.35 m wide along their own X and `GateYawFix` turns the mesh, so handing the gate the run
direction instead lies them ACROSS the wall — where 2.35 m of door disappears inside 3.5 m
of masonry. The gate is built, recorded, openable, and completely invisible. `GateBlockSegments`
reads the same yaw, so that mistake also puts the seal through the stone rather than across
the opening. `check_castle_gateway.py` asserts both directions now.

The mark is what persists (`QMCastleGw`), not the tile: which tile becomes an archway is
worked out again at every rebuild, so a gateway travels with the wall if the run is ever
refitted under it. The leaves are tagged `gateway` and come down and go back up with the
wall they hang in — untagged gates are the player's palisade gates and are left alone.

### A run finishes its own ends

`CastleTowerEnds` puts a tower on the open end of a run, which is right for a palisade and
wrong here: the mod's own tower on the end of the Kuttenberg curtain is a different wall's
block, at a different height and in different stone, and it reads as **a corner that failed
to appear** rather than as a finish. A type that owns a lid now takes the lid instead
whenever the selected tower is not one the wall owns (`own`, the same test the tower
offsets already use). Measured over 128 open runs: 256 mismatched end towers before, 0 after.

### Nobody buys a gatehouse

A wall you cannot walk through is no use, so the quartermaster sells the **wall** — 3000
groschen for the stone curtain (`LogiBuyCastleWall`, which is `merc_castle_build` with a
price on it) — and the gatehouse comes with it. `CastleGatewayAuto` cuts one the moment the
run is finished.

"Somewhere convenient" is two rules. It goes on a **straight stretch with a whole tile
either side**: a gatehouse jammed against a corner has nowhere to put its approach and the
corner's own arm would swallow half of it. Among those it goes on the side of the camp the
player is **standing on**, which is the side they have been walking in and out of while
building the thing. One per wall — asking again does nothing, and clearing the wall takes
the gateway with it.

`merc_castle_gateway` still places extra ones by aim, and `merc_castle_gateway_clear`
removes them. `tools/check_castle_gateway.py` checks the tile, its lift, that the leaves
land inside the opening, that a rebuild does not hang a second set, that clearing puts plain
curtain back, and that a finished wall cuts its own way through on a straight stretch.

## Fitting a piece

Outside the `fence` and `seg` groups, every `len` in `CastleWalls` is a **guess**. A `.cgf` carries no usable bounding box (see the mesh-enumeration notes in
[gates.md](gates.md)), so the only way to size a piece is to build with it:

1. `merc_castle_rects` (or `merc_castle_matrix <group>`), walk it, then `merc_castle_wall <n>`
2. `merc_wall_len <m>` until the seam between two pieces closes
3. `merc_wall_up <m>` until it sits on the ground rather than floating or sunk
4. `merc_wall_yaw 90` if the pieces run across the edge instead of along it
5. `merc_castle_tune` — prints the fitted segment and tower as table rows, and stores the
   numbers on the live type for the rest of the session

Paste those rows back into `mercenaries_castle.lua` to make them the defaults.

## Commands

| Command | Use |
| --- | --- |
| `merc_castle_square [tiles] [tiles across]` | lay an EXACT rectangle — the only way to get one that closes |
| `merc_castle_rects [picks\|group\|all] [side] [gap]` | a closed rectangle of each candidate, laid out to walk round |
| `merc_castle_tower_row [wall] [tiles] [gap]` | every tower candidate, with the curtain running into it |
| `merc_castle_matrix [group\|all] [runlen] [pitch] [towers 0\|1]` | lay a group out as tiled sample runs |
| `merc_castle_matrix_clear` | remove the sample runs, rectangles and tower rows |
| `merc_wall_level 0\|1` | lay a stone run at one height instead of stepping it down the slope |
| `merc_castle_build` | start drawing |
| `merc_castle_gateway` | cut an EXTRA way through the wall where you aim (a finished wall already cuts itself one) |
| `merc_castle_gateway_clear` | take every gateway out again |
| `merc_castle_ghost [n]` | which stone fence the build projection is drawn with |
| `merc_wall_close_snap <m>` | how near the first corner the aim closes the ring (0 = off) |
| `merc_castle_wall <n>` | stone segment (no arg lists them) |
| `merc_castle_tower <n>` | corner tower, 1 = none (no arg lists them) |
| `merc_castle_gate <n>` | which gate the run closes with (no arg lists them) |
| `merc_castle_towers 0\|1` | corner towers on or off (castle wall types only — a palisade never takes one) |
| `merc_castle_tower_every <n>` | a tower every n corners: 1 = every corner, 0 = none |
| `merc_castle_corners 0\|1` | corner pieces on the turns without a tower |
| `merc_castle_ends 0\|1` | towers on the open ends of a run as well as its corners |
| `merc_castle_thick <m>` | thickness of the back-face copy |
| `merc_castle_back 0\|1` | double the current segment, for one that turns out hollow behind |
| `merc_castle_tower_up <m>` / `merc_castle_tower_yaw <deg>` | sink or spin the towers |
| `merc_castle_status` | what is currently set |
| `merc_castle_tune` | print the fitted segment and tower as table rows |
| `merc_castle_off` | back to the palisade wall type, towers off |
| `merc_castle_help` | the list above, in game |

## What persists

`QMCastle` carries the tower index, the towers/ends flags, the thickness, the tower
offsets, the gate style, the tower spacing and the corner-piece flag into the defence
save, next to `QMWallType` and the run point lists. Everything on a corner — towers,
corner pieces, the doubled faces — is generated at rebuild time, so without it a reloaded
stone wall would come back bare, cornerless and see-through. A save written before the
corner pieces went in simply keeps the defaults (a tower every other corner).
