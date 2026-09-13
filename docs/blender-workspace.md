# Blender workspace

A Blender file with the game's own props to place, the game's own surfaces to paint with,
and the mod's castle kit to build against — plus the road back out: what you arrange in
Blender becomes a **prefab** the mod spawns in game.

```
powershell -ExecutionPolicy Bypass -File .\assets\make_blender_workspace.ps1
```

Then open `..\kcd2_blender\kcd2_workspace.blend`.

Everything it writes is **derived from the installed game** — geometry read out of the
paks, textures decoded out of them — so it is built outside the repo, never committed and
never shipped. Delete the folder and rebuild it whenever you like.

## What you get

| | |
| --- | --- |
| `kcd2_props.blend` | **299 props** as drag-out assets, each with a thumbnail: ladders, sacks, crates, carts, barrels, cauldrons and camp fires, rocks, firewood, pavises, tarases, targets, anvils, tables, lamps… |
| `kcd2_materials.blend` | **502 surfaces** — the game's shared PBR library (`materials/substance`, `materials/terrain`) plus wall, roof, tent and fence materials — as material assets |
| `kcd2_mod.blend` | our own castle kit — three wall variants, the three corners, the tower — so a new piece can be modelled against what it has to meet |
| `kcd2_workspace.blend` | the file you actually open |
| `textures/` | 1,182 decoded PNGs, referenced relatively so the folder can be moved |

Workspaces along the top: **KCD2 Build** (viewport + Asset Browser), **KCD2 Model**
(modelling), **KCD2 UV**, **KCD2 Shade** (shader editor). The scene is metric, the
viewport clips at 2 km rather than 100 m, and it opens in Material Preview so the textures
are on screen.

**One thing to do on first open:** in the Asset Browser (bottom of *KCD2 Build*), pick
**KCD2** in the library dropdown, top left. Which library a browser shows cannot be set
from a script — a file browser's settings only exist once it has been drawn, and the build
runs headless — so that one click is yours. It sticks after that.

There is a 1 m wireframe cube at the origin. It is a scale reference — Henry is about
1.8 m, a wall walk is 4.9 m up, our curtain is 4.00 m per segment.

## The loop

1. **Place.** Drag props out of the Asset Browser. Every one carries the path of the
   `.cgf` it came from, which is what makes the rest of this work.
2. **Model.** Build your own geometry in the same scene, to the same scale, against the
   real props.
3. **Export the arrangement.**
   ```
   blender --background <your.blend> --python assets/blender/prefab_export.py -- <name>
   ```
   Writes `data/Scripts/mods/prefabs/<name>.lua`: one row per prop, model + position +
   rotation, measured from an Empty called `origin` if there is one and from the world
   origin if not.
4. **Spawn it.** `merc_prefab_spawn <name>` in game drops the whole arrangement where you
   stand, facing the way you face. `merc_prefab_clear` takes it away again.

Your own geometry is *not* in the prefab — it is not a `.cgf` yet. That is the next
section.

## Taking a wall you modelled into the game

```
powershell -ExecutionPolicy Bypass -File .\assets\build_wall.ps1
```

One command: Blender → FBX → `rc.exe` → `.cgf`, plus the `.mtl` and the clutter list.
Model the wall, leave the props sitting on it, save, run it. Nothing needs preparing by
hand — `assets/blender/export_wall.py` does the four things that stand between a mesh and
a wall the builder can tile:

* **Squares it up.** Applies the object's transform (yours was still on a 5 × 0.94 × 3
  scale), centres it in X and Y and drops its base to z = 0, so the builder's spacing
  means what it says and the piece straddles the line it is drawn along.
* **Assigns the materials by rule**, because a hand-modelled wall has no slots. See below.
* **Gives it collision.** Two Nodraw boxes, body and parapet. Without them the player
  walks straight through.
* **Lifts the props off it** into `data/Scripts/mods/prefabs/wall_<name>_decor.lua`.

### The material rule, and why patches are not materials

Two visible submaterials, not four:

| slot | what |
| --- | --- |
| `wall` | `wall_a`, with `wall_b` blended in low down — a weathered foot |
| `walk` | `wall_c`, with compacted earth blended down the middle — a worn track |

The walkway is found, not configured: the largest up-facing surface that is not the merlon
tops.

**Where the second stone shows is not a material at all — it is vertex alpha.** A face
carries exactly one submaterial, so painting patches *as materials* can only draw them
along face edges: the first attempt produced metre-wide rectangles, and subdividing to
0.5 m only produced smaller rectangles. CryEngine's Illum shader has a blend layer —
a second diffuse (`Custom`) and normal (`[1] Custom`) mixed in per pixel, driven by
vertex alpha and broken up by a mask texture — and alpha interpolates *across* a face, so
the transition is a gradient. That is the whole difference between "blocky" and "soft".

Three things had to be true for it to work, and each cost a round to find:

* **Vertex colours survive the pipeline.** Blender's FBX carries them and `rc.exe` writes
  them as stream type 3; `tools/cgf_mesh.py` reads them back, so it can be checked.
* **The gen mask must be copied, not invented.** `BLEND_GENMASK` in `material_set.py` is
  lifted verbatim from the game's own stone-and-plaster blend on the Trosky gatehouse. It
  is a shader permutation id; a wrong one drops the effect silently.
* **Alpha runs 0 to 1, not around 0.5.** Sample a shipped wall that uses a blend material
  and its alpha is bimodal — a pile at 0, a pile at 255, a thin spread between. Centring
  the noise on 0.5 shows the second stone at half strength over the whole wall.

The walk is subdivided four times finer than the wall (0.22 m against 0.55 m) because
alpha can only turn where there is a vertex, and the walk is a narrow strip — at the
wall's spacing its patches came out with straight axis-aligned edges.

### Variants

`--variants a,b,c` writes one mesh per variant. They are the same geometry with the noise
field **reseeded and rotated**, and each is normalised to the same mean alpha, so what
differs between them is where the weathering falls and not how much there is — a run where
one length is visibly grubbier than the next reads as a mistake, not as variety. The wall
type lists them in `vary` and the builder cycles them along the run.

Palette, texture paths and the blend parameters live in `assets/material_set.py` under
`WALL_HAND`; the slot order there IS the contract with the mesh.

### Clutter

Props left standing on the wall are not baked into it — the same barrel every ten metres
reads as wallpaper. They go into a decor list, and the builder scatters a few per segment:

```lua
{ n = "crenel_hand", ..., decor = "crenel_hand", decorCount = 3 }
```

Which few is chosen by hashing the segment's own position (`WallSpawnDecor` in
`mercenaries_wall.lua`), not `math.random` — the run has to come back identical after a
rebuild or a reload, and seeding the global RNG to get that would reach into everything
else that rolls a number.

### The length

The exporter prints `[len]`, the mesh's real length. `len` in `CastleWalls` should be a
centimetre **under** it: two bevelled ends butted together leave a hairline seam down
every joint of a run, and a centimetre of overlap is invisible.

## The tools that matter

You know how to model; this is the part that is specific to shipping into KCD2.

**Getting around.** `N` opens the sidebar — the Item tab shows real dimensions in metres,
which is the fastest sanity check there is. `Shift+~` for fly navigation to walk a scene
at human height. Numpad `.` frames the selection.

**Snapping.** `Shift+Tab` toggles it; the magnet dropdown picks what it snaps to. For
prop placement use *Face* with *Align rotation to target* so a barrel lands sitting on a
cart bed rather than through it. `Ctrl+drag` snaps a single move without toggling.

**The modifiers worth knowing here**, roughly in the order they earn their keep:

| Modifier | What it is for |
| --- | --- |
| **Mirror** | model half a gate, a tower face, a cart |
| **Array** | palisade stakes, merlons, corbels, ladder rungs — `Fit Length` gives you a real metre count |
| **Bevel** | the single biggest quality lever. Nothing in a game is a perfectly sharp edge; 1–3 cm of bevel is what catches light. Use **Weight** or **Angle** limit, and turn on *Harden Normals* |
| **Solidify** | boards, shields, plate: gives a plane thickness without modelling both sides |
| **Weighted Normal** | fixes the shading of a bevelled hard-surface mesh; put it last |
| **Decimate** | LODs, if you make them |

**Booleans.** *Exact* mode only, and cut a **single closed solid** with a **single closed
solid**. Cutting a pile of overlapping boxes deletes the whole target — that trap cost a
day on the castle kit and is written up in [custom-assets.md](custom-assets.md).

**Smooth shading.** 5.x has no Auto Smooth checkbox any more: `Object > Shade Auto Smooth`
adds a modifier that does it by angle. Use it, or the bevels look like dents.

**UVs.** Most KCD2 surface materials are *tiling* — `U` → **Cube Projection** or **Smart
UV Project**, then scale the island so the stone is the right size in metres, rather than
unwrapping to a 0–1 square. Turn on *Correct Face Attributes* when you move geometry after
unwrapping. The N panel in the UV editor shows the pixel density if you need to match a
neighbouring piece.

**Add-ons worth switching on** (Edit > Preferences > Add-ons):

* **Node Wrangler** — select an image node, `Ctrl+Shift+T` wires a full texture set at
  once; `Ctrl+T` adds mapping nodes.
* **F2** — better `F` fill behaviour.
* **LoopTools** — *Space*, *Circle* and *Bridge* when you are fixing someone else's mesh.
* **Extra Objects** — parametric primitives to start from.

**Measuring.** The Measure tool (`M` in the toolbar) puts a ruler in the scene. Anything
the player walks through wants ≥ 1.0 m clear and ≥ 2.1 m headroom; anything they fight in
wants more.

## What the engine needs from a mesh

These are the rules the mod's own pipeline already follows — worth knowing before you
build something that has to go back in.

* **Metres, Z up.** Blender's defaults are already right. Never scale the object; scale
  the mesh (`Ctrl+A > Scale` after).
* **Material slot ORDER is the contract.** A face names a submaterial by *index*, so slot
  0 in Blender is submaterial 0 in the `.mtl`. `assets/material_set.py` generates both
  ends from one table so they cannot drift.
* **Collision is a material, not a mesh.** Faces wearing the `Nodraw` submaterial are the
  physics proxy. No Nodraw faces means a prop you walk straight through.
* **Triangles.** The game's own props run from 300 (a stone) to 20,000 (a cart). Nothing
  needs to be under a strict budget, but 40k for a barrel would be silly.
* **rc.exe compiles it.** Blender writes FBX, the game's own resource compiler turns it
  into `.cgf`. `assets/build_castle_kit.ps1` is the working example, end to end.

## Reading the game's own assets

The reader is `tools/cgf_mesh.py`, and it is useful on its own:

```
python tools/cgf_mesh.py objects/manmade/vehicles/carts/cart_a.cgf
python tools/cgf_mesh.py --obj cart.obj objects/manmade/vehicles/carts/cart_a.cgf
```

KCD2 splits a static mesh in two: the `.cgf` is the scene graph and carries no vertices at
all, and the streams live beside it in a `.cgfm`. Both are CryEngine chunk files. The
notes on the format are in the module docstring; the parts that cost the most to work out
were the 16-byte interleaved half-float vertex stream and the 36-byte mesh subset stride
(get that wrong and every mesh lands on submaterial 0, which paints a ladder with its own
collision proxy).

`tools/cgf_nodes.py` answers the other question — whether a `.cgf` is one prop or a whole
baked level section. Spawning a level section as a prop tiles a castle on top of itself.

### Textures

`assets/extract_textures.py` decodes them. Two things about KCD2's:

* They are **streamed**. The `.dds` in the pak is a stub with the header and the smallest
  mips; the picture is in `.dds.1` … `.dds.N` beside it, N largest. Which mip a file holds
  is worked out by matching its byte count against the header's dimensions, which is exact
  and copes with the non-square tiling textures.
* Every normal map is **BC5_SNORM** (DXGI 84) — *signed* endpoints. Decoding those as
  unsigned picks the wrong interpolation mode roughly half the time (`0x22` is +34, `0xFD`
  is −3, but unsigned they read as 34 < 253) and the result is confetti that looks enough
  like surface detail to survive a glance. It cost a rebuild to spot: the diffuse maps
  were perfect while every surface rendered faintly speckled.

## Adding to the library

`assets/blender/kcd2_catalog.py` is the list. Add a row — catalog, folder, names — and
rebuild. `"*"` takes a whole folder. Anything it cannot find is reported by name rather
than skipped silently. To go looking for candidates:

```
python tools/cgf_nodes.py --single ladder      # single-object meshes matching "ladder"
python tools/cgf_mesh.py <path>                # size, part count, material library
```

Left out on purpose: composite meshes (a whole village in one file), whitebox blockouts,
and anything alpha-cut — foliage and cloth cards come in as solid sheets, which reads
worse than not having them.

There is no brazier in KCD2. What the game uses for a camp fire is a tripod and a stack of
wood: `camp_cooking_a/b/c`, `fireplace_wood_a/b/c` and the `cauldron_*` family, all under
**Props/Camp/Fire**.

## Commands

| | |
| --- | --- |
| `make_blender_workspace.ps1 -Only props` | rebuild just the prop library |
| `make_blender_workspace.ps1 -Size 1024` | bigger textures (slower, sharper) |
| `make_blender_workspace.ps1 -NoRegister` | build, but leave Blender's preferences alone |
| `merc_prefab_spawn <name>` | drop a prefab where you stand |
| `merc_prefab_list` / `merc_prefab_clear` | what is loaded / take it away |
