---
title: Assets pipeline
summary: How to get your own static meshes, materials and textures into KCD2 (Blender -> FBX -> rc.exe -> .cgf), how to read and enumerate the game's own assets, and how to spawn static geometry without a custom entity class.
tags: [assets, engine, tooling, world]
kind: reference
status: current
scope: kcd2
verified: release_1_5
---

# Assets pipeline

## TL;DR

- The game's own resource compiler, `KCD2Mod\Tools\rc\rc.exe` (free **KCD2 Modding Tools** Steam app), takes **FBX
  directly** and writes `.cgf` chunk version `0x746`, identical to shipping assets - Blender's built-in FBX export is
  enough, no BCry addon (verified in game: custom-assets.md).
- **rc.exe ignores unknown switches silently**, and `/mtl` does nothing on the FBX path: the compiled material library
  is always `default`. Fix it after compile (`tools/cgf_setmtl.py`) or apply the material at spawn with
  `Entity.SetMaterial` (retail tool behaviour, measured).
- **Material slot order is the contract** between mesh and `.mtl`; **collision is a `Nodraw` submaterial** with a
  `SurfaceType`, not a separate mesh. One *visible* material per `.cgf` (verified in game; official wiki KM-A-48).
- Every mesh the game ships is listed in the zip directories of `Data/IPL_Objects-part*.pak` (16,541 `.cgf`); the plain
  `Objects-part*.pak` hold none (verified).
- A static prop needs no custom class: `System.SpawnEntity{class="BasicEntity", properties={object_Model=...}}` - but
  `BasicEntity` defaults to a **pushable rigid body**; pass `Physics` explicitly (vanilla: `BasicEntity.lua`).

## The toolchain

| Piece | Where | Notes |
| --- | --- | --- |
| Modding Tools | Steam app 2429020, installs as `KCD2Mod` | same folder layout as the game; dev build in `Bin\Win64ReleaseSteamLTO_DLL`; install near a drive root (255-char path limit) (official wiki KM-A-55) |
| `rc.exe` | `KCD2Mod\Tools\rc\rc.exe` | loads `ResourceCompilerFBX.dll`; also packs paks and compiles textures/shaders |
| Example assets | `KCD2Mod\Data\objects\enviro_asset_template\` | `Assets_Template.max`, four reference `.cgf` + `.mtl` + source `.tif`, `.cgf.dfp` property sidecars (shadow, LOD, collision-class flags) |
| Official DCC route | `Tools/enviro/` 3ds Max plugin, `Tools/maya/` | the wiki's pipeline is 3ds Max (KM-A-41..43, KM-A-66); this repo uses Blender + FBX instead |
| Blender scripts (this repo) | `assets/blender/*.py`, `assets/build_*.ps1` | generate meshes headless, export FBX, compile, copy into `data/Objects/...` |

A mod's `.cgf` and its `.mtl` ship under `Data/Objects/<yourmod>/...` inside the mod pak like any other data; textures
can point at the base game's own `.tif` paths so none need shipping (verified in game).

## Compiling: Blender -> FBX -> rc.exe -> .cgf

Worked end to end in `assets/build_castle_kit.ps1` / `assets/build_wall.ps1`: script builds the mesh, exports FBX,
`rc.exe` compiles, output copied into `data/Objects/...`.

| Trap | What actually happens | Source |
| --- | --- | --- |
| Misspelled switch | RC **silently ignores** unknown switches. The node-merge switch is `/mergeallnodes` (not `/mesh_merge_nodes`); with merging left on the object's name becomes `Merged` | verified |
| `/mtl` | does nothing on the FBX path; the `MtlName` chunk (`0x1014`) always says `default`, with or without the switch or a sibling `.mtl`. Submaterial **names** from Blender are preserved | verified |
| Fewer chunks than shipping assets | no `4110/4115/4120` node chunks. Not a broken export: `/cgftofbx` on a shipping asset and recompiling gives the same reduced structure. Renders fine | verified in game |
| Split mesh | shipping assets are built by `RCJob_WH.xml` with `SplitMeshFile="1"`, `StripMesh="1"`: geometry goes to a sibling **`.cgfm`**, the `.cgf` is a few KB of structure. A mod `.cgf` can keep geometry inline | retail files |
| Triangle counts differ | RC removes degenerate triangles | measured |
| Unused material slots | RC **compacts** unused slots, shifting later submaterials down. Remap embedded material names to a fixed shared slot table after compile (`tools/cgf_castle_materials.py`) | measured |
| `MtlName` patch | the name lives in a fixed 128-byte field followed by the submaterial count; rewriting it must keep that field size and recompute the chunk table (`tools/cgf_setmtl.py`) | measured |
| **rc.exe returns before its output is on disk** | patch the `.cgf` straight after and RC's late write lands on top, resetting `MtlName` to `default` - the piece silently loses its collision. Wait until the file stops changing, and read the library name back before installing (`assets/build_wall_pieces.ps1`) | measured (castle.md) |
| OBJ as an intermediate | OBJ carries **no vertex colour**. Vanilla wall materials with `%VERTCOLORS` / `%BLENDLAYER` choose between two textures by vertex **alpha**, so a mesh round-tripped through OBJ renders as different stone. Move meshes as raw arrays; keep the reader's BGRA order both ways and export `colors_type="LINEAR"` (blend data, not display colour) | verified in game (castle.md) |

The material library is not cosmetic: the engine reads the submaterials to find the `Nodraw` proxy, so a `.cgf` whose
library cannot be resolved gets **no collision** (`tools/cgf_setmtl.py`). The Mercenaries build does both halves: it
patches `MtlName` to the real path and remaps each piece's submaterial indices to the kit's shared 7-slot table
(`tools/cgf_castle_materials.py`; the proxy slot is `Shader="Nodraw"` with `SurfaceType="mat_rock_unwalk"`, written by
`assets/make_mtl.py`), and still calls `ent:SetMaterial` at spawn (custom-assets.md).
Whether `SetMaterial` alone gives collision is unverified - patch `MtlName`.

## What a mesh must carry

- **Metres, Z up**; apply scale to the mesh, never leave it on the object (verified).
- **Slot order = submaterial index.** A face names its submaterial by index; generate the Blender slots and the `.mtl`
  from one table so they cannot drift (`assets/material_set.py`).
- **One visible material.** A second *drawn* material on some vertices does not render. A `Nodraw` physics-proxy
  submaterial alongside it is fine and is how vanilla does it (verified in game; official wiki's "1 material" rule).
- **Collision = faces on a submaterial with `Shader="Nodraw"` and a `SurfaceType`** (vanilla
  `wall_segments_220_60_a.mtl` calls it `proxy`). No such faces = the player walks through (verified in game).
  In 3ds Max terms: material ID set to "Physicalize: Physical proxy (No Draw)"; primitives (sphere < capsule < cylinder
  < box < trimesh, cheapest first) are preferred; proxy node names contain `proxy` (official wiki KM-A-48).
- **Never put a proxy face exactly on a render face**: the export weld merges the pair and the `Nodraw` face can win,
  deleting that piece from the render. Inset the hull (12 mm used) (verified in game).
- **Node conventions RC actually knows**: `$physics_proxy`, `$collision`, `$lod` (from `ResourceCompilerPC.dll`);
  `$lod1_<name>`, `$lod2_<name>` linked to LOD0 (official wiki KM-A-46). `$move`, `AIRadius`, `NotTriangulate` do
  **not** exist in the game binary - legacy fields the RC still writes into `.cgf.dfp` (retail binary).
- **Vertex colours survive** FBX -> RC (stream type 3); vertex alpha drives the Illum shader's blend layer (second
  diffuse/normal mixed per pixel, broken up by a mask). Copy the shader **gen mask** from a vanilla material that uses
  the blend - a wrong one drops the effect silently - and use bimodal alpha (0 or 1, not centred on 0.5) (verified in game:
  blender-workspace.md).
- Budgets (official wiki KM-A-45/46/54): CryEngine limit **64,000 indices** per mesh; starting points 0.1 m3 = 1k tris,
  1 m3 = 5k, 10 m3 = 20k; texel ratio **512 px/m** diffuse at LOD0 (`r_TexelsPerMeter 512` to view); LOD1/LOD2 each
  >= 50% reduction, `LodRatio` 255 / 200 / 150 for big houses / big objects / furniture. Vanilla props run 300 (a stone)
  to 20,000 (a cart) tris (measured).
- Standard dimensions (official wiki KM-A-52): floor heights 225/250/300/350/400 cm; wall thickness 10/25/60/100/150/200 cm
  (25 timber, 60 stone city house); stair step 20 cm; ladder rung pitch 20 cm; seat height 45 cm.

Surface types matter beyond sound: they set pierceability, NPC see-through, **walkability (whether navmesh is generated
on it)**, `player_only` / `horse_only` collision, stairs (`slope`, `stairs_wood`, `stairs_stone`); `wood_unwalk` generates
no navmesh. Debug with `p_draw_helpers 1` (missing surface type shows bright purple) and `p_draw_helpers s_t(1)` for
proxy bounding boxes (official wiki KM-A-48). Surface names/ids from Lua:
[`System.GetSurfaceTypeNameById`](api/System.md#getsurfacetypenamebyid) /
[`GetSurfaceTypeIdByName`](api/System.md#getsurfacetypeidbyname).

Occlusion (`occluder.ocm`) and shadow proxies are authored in the level/editor and are only relevant if you ship level
data (official wiki KM-A-47, KM-A-49); see [world-and-physics.md](world-and-physics.md#levels-and-regions).

## Blender booleans (for generated kit meshes)

All three fail silently - the build succeeds and the model is wrong (verified in renders, custom-assets.md):

1. **FAST** solver leaves the cutter behind as stray faces; bounding box far bigger than the dimensions. Use **EXACT**.
2. EXACT on a target that is **not one closed solid** (interpenetrating boxes) can delete the whole shell being cut.
3. EXACT with a cutter that is **not one closed solid** (overlapping boxes) can leave **zero** polygons. Cut one clean box
   at a time and assemble afterwards.

Mandatory cheap check for generated meshes: print the **face count per material slot** and refuse to continue if a slot
that should have geometry is empty - it would have caught three silent failures that survived renders and art review.

## Reading the game's own assets

| Question | Tool / method |
| --- | --- |
| Every mesh that exists | read `Data/IPL_Objects-part*.pak` as zip directories (`zipfile.namelist()`, nothing unpacked). Level object lists only reference what that level uses and under-report |
| Is a `.cgf` one prop or a baked level slice? | `tools/cgf_nodes.py` - 1 node = prop, <= 6 = prop with parts, > 6 = level slice (e.g. `suchdol_fortress_walls.cgf` is the whole fortress); `*whitebox` material = blockout |
| Geometry, materials, OBJ export | `tools/cgf_mesh.py <path> [--obj out.obj]` |
| Where does it collide? | `tools/cgf_proxies.py` - lists `$physics_proxy_*` nodes as world AABBs, `--crate` emits collider rows |
| Textures | `assets/extract_textures.py` |

Format facts (measured, documented in the tools' docstrings):

- Chunk file: `"CrCh"` + version `0x746` + chunk count + table offset; 16-byte table entries `{type, version, id, size,
  offset}`. Types: `0x1000` Mesh, `0x100B` Node (name[64], object id at +64, 4x4 transform at +84), `0x1014` MtlName,
  `0x1016` DataStream, `0x1017` MeshSubsets.
- Shipping static meshes split into `.cgf` (scene graph, proxies, material name - no vertices) and `.cgfm` (render
  streams). Vertex stream type 15 is **16-byte interleaved**: 3 half-float position + pad, 4 bytes colour, 2 half-float UV.
  Mesh subsets stride **36 bytes** - get it wrong and every face lands on submaterial 0 (a ladder painted with its own
  collision material).
- Proxy nodes are named `$physics_proxy_<artist name>` and live in the `.cgf`, not the `.cgfm`. Level-scale meshes put
  their hull tens of metres from the origin.
- The "sibling `cv_*.cgf` means the mesh has no hull of its own" heuristic is **not reliable**
  (`malesov_wall_tower.cgf` has a `cv_` sibling and 40-odd inline proxies) - run `cgf_proxies.py` instead
  (measured; walls-and-sieges.md).
- A mesh's visual origin is often **not** its body centre (`palisade_wall_a_v3` sits 0.18 m off; a closed and open gate
  pair differ by 0.13 m); measure offsets from the mesh (`tools/measure_gate.py`), never tune them by eye.
- Textures are **streamed**: the pak `.dds` is a stub (header + smallest mips); the image is in `.dds.1` .. `.dds.N`
  (N largest). Identify which mip a file holds by byte count vs header dimensions.
- Every normal map is **`BC5_SNORM`** (DXGI 84, signed endpoints). Decoding as unsigned picks the wrong interpolation
  about half the time -> fine speckle that passes for surface detail.
- UI and map icons have their own DDS header traps - see [ui-scaleform.md](ui-scaleform.md#images-and-icons).
- **Tile pitch of a modular wall piece** is the commonest body width across half-metre height bands, not the bounding
  box (parapet overhangs jut past each end precisely to lap the neighbour; tiling on the bbox opens a gap) and not a
  percentile (trims the wrong end). All ten `wall_kh_*` city-wall variants then agree on 12.39 m (measured:
  `tools/measure_walls.py`, castle.md).
- **Kit meshes are open shells at their ends**: `wall_kh_a.cgf` and its family have no geometry across either end face,
  because in the level another piece always stands there. A run's own ends are see-through (backface culling) unless
  capped (measured, castle.md).
- **Shadow proxies look like floors**: a shadow-proxy node is upward-facing geometry, and counting it when measuring
  decks invents platforms nothing can stand on. Measure on render meshes only (measured, castle.md).
- Missing `lod2_*` textures named by some vanilla meshes are harmless when the spawner forces
  [`SetLodRatio(255)`](api/Entity.md#setlodratio): the LOD chain is never reached (castle.md).

blender-workspace.md builds a Blender asset library (299 props, 502 surfaces, decoded textures) from the installed
game with `assets/make_blender_workspace.ps1`, and exports arrangements back as spawnable prefab tables
(`assets/blender/prefab_export.py`). Derived game content: build locally, never commit or ship it.

## Spawning static geometry without a custom entity class

```lua
local ent = System.SpawnEntity({
    class = "BasicEntity", name = "MyProp_1",
    position = pos, orientation = dirVec,           -- orientation is a DIRECTION vector
    properties = {
        object_Model = "objects/props/.../thing.cgf",
        Physics = { bPhysicalize = true, bRigidBody = false },  -- static, collides
    },
})
ent:SetAngles({ x = 0, y = 0, z = yaw })          -- yaw (radians, (unverified)); a different zero from `orientation`
```

- `BasicEntity` (vanilla `Scripts/Entities/Physics/BasicEntity.lua`): `OnSpawn -> SetFromProperties -> SetupModel ->
  LoadObject(0, object_Model) + PhysicalizeThis()`. No `.ent`, no script of your own.
- **Physics defaults**: the class declares `Physics = { bPhysicalize = true, bRigidBody = true, bPushableByPlayers =
  true }`. Omitting `Physics` does **not** make a walk-through prop - it makes a pushable rigid body NPCs can step onto.
  For no collision pass `{ bPhysicalize = false, bRigidBody = false }` and call
  [`DestroyPhysics()`](api/Entity.md#destroyphysics) after spawn (verified in game: camp.md).
- A mesh with `$physics_proxy` nodes collides when spawned **provided the spawn-time `properties` table carries
  `Physics`** - properties are read when the entity physicalises, before class defaults can be relied on (measured,
  `tools/cgf_proxies.py`). Spawned props that "don't stop the player" are commonly this; the robust fallback is a line of
  `PE_STATIC` crate colliders hidden with [`DrawSlot(0, 0)`](api/Entity.md#drawslot) (render slot dropped, physics
  kept), layered at several heights so they cannot be vaulted (verified in game: gates.md).
- **Orientation**: `SpawnEntity`'s `orientation` is a forward direction vector whose zero is a quarter turn from
  `SetAngles`' yaw zero. Same number to both = a quarter-turn mismatch, invisible on round props, obvious on a bed
  (verified in game).
- A mistyped `object_Model` spawns an entity that renders nothing, with no error - assert paths against the paks
  (`tools/check_campui.py` does).
- A spawned prop is snapped onto whatever is directly above the given (x, y) - a **roof** included - regardless of the
  requested z; you cannot place a prop inside a building by z alone (verified in game: camp.md).
- Materials at runtime: [`Entity.SetMaterial`](api/Entity.md#setmaterial). A single-submaterial `.mtl` on a
  multi-submaterial mesh maps only slot 0; every other submesh stops drawing.
- Re-created entities come back at the default view distance; re-pin with
  [`SetViewDistRatio`](api/Entity.md#setviewdistratio) / [`SetViewDistUnlimited`](api/Entity.md#setviewdistunlimited)
  when re-spawning (verified in game: gates.md).

### Custom entity classes

Needed for per-frame updates, use prompts, or custom physics. Two files, both required or `System.SpawnEntity` throws:

```
Data/Scripts/Entities/<Name>.lua     the class table
Data/Entities/<Name>.ent             <Entity Name="<Name>" Script="Scripts/Entities/<Name>.lua"/>
```

- Updates go in `<Name>.Client:OnUpdate(dt)` / `<Name>.Server:OnUpdate(dt)`, never a top-level `OnUpdate`.
- **Do not call `EntityCommon.MakeUsable` after defining your own `IsUsable`/`OnUsed`**: it redefines `IsUsable` (gated on
  `bUsable`) and overwrites `OnUsed` (unless yours is named `Base_OnUsed`); `AnimDoor`, `Ladder`, `Bed` skip it (vanilla
  `EntityCommon.lua`). Door-style prompts can reuse `@ui_door_open`/`@ui_door_close` and the `inr_doorOpen`/`inr_doorClose`
  filters from `Libs/Config/interaction_filter.xml` with no new data.
- An `OnUsed` that destroys/replaces its own entity (e.g. a mesh swap) must defer the work a tick.
- Collision classes, rigid vs static for AI obstacles: [world-and-physics.md](world-and-physics.md#physics-and-collision).

## Shipping level data

Editing a level is "not fully supported": most export products (navmesh, streaming layers, HLODs, GI, soul lists,
brushes, entity lists, terrain) cannot be merged, so a level mod ships the whole set of paks and conflicts with every
other level mod and future patches. Mergeable: tables in `level.pak/tables` (scheduler links, cat waypoints, dog points,
smart-object animations), patched like `Libs/Tables`. Export needs Sandbox (`Editor.exe`), ~64 GB RAM for Kuttenberg,
1.5-2.5 h, then `rc.exe /job=Tools/rc/RcJob_WH_level.xml` to produce `recast.pak` (official wiki KM-A-92). Consequences
for runtime geometry: [world-and-physics.md](world-and-physics.md#navmesh).

Shaders ship precompiled in `Engine/Shaders.pak`; modified shaders need `ShaderCacheGen.exe` and an RC `ShadersAll`
job (official wiki KM-A-82).

## Gotchas

- Compiled `.cgf` has no material / no collision in game -> `MtlName` says `default`; patch it or `SetMaterial` at spawn.
- `MtlName` patch "didn't stick" and collision is gone -> rc.exe was still writing; wait for the output to settle, then patch.
- A piece cut from a vanilla wall looks like different stone -> vertex colours (blend alpha) were lost on an OBJ round trip.
- Tiled wall shows a thin gap at every joint -> pitch taken from the bounding box; use the commonest body cross-section.
- The end of a wall run is see-through -> vanilla kit pieces are open shells at the ends; cap them or end on a tower.
- A compiler switch "has no effect" -> RC silently ignores misspelled switches; check the exact name.
- Your object is called `Merged` -> node merging is on by default; pass `/mergeallnodes` deliberately or not at all.
- Trim/proxy faces render with the wrong material after compile -> RC compacted unused slots; remap names to fixed slots.
- A wall piece is invisible in game but fine in Blender -> a proxy face coincided with a render face and the weld kept
  the `Nodraw` one; inset the hull.
- Whole mesh vanished after a boolean -> non-closed target or compound cutter under EXACT; FAST leaves cutter debris.
- Second material on a mesh doesn't render -> one visible material per `.cgf`.
- Everything reads submaterial 0 when parsing a `.cgfm` -> mesh-subset stride is 36 bytes.
- Decoded normal maps look speckled -> they are `BC5_SNORM`; decode as signed.
- Mesh enumeration misses files -> you scanned `Objects-part*.pak`; only `IPL_Objects-part*.pak` contain `.cgf`.
- A "wall" mesh tiles whole castles on top of each other -> it is a baked level slice; check the node count.
- Spawned decoration is solid / NPCs stand on stools -> `BasicEntity` defaults to a rigid body; pass `Physics` explicitly.
- Player walks through a spawned mesh that has a proxy -> spawn `properties` lacked `Physics`; else use hidden crate colliders.
- A spawned prop lands on the roof -> spawns snap to the topmost surface over (x, y).
- Smart object / bed a quarter turn off its mesh -> `orientation` (direction vector) and `SetAngles` (yaw) have different zeros.
- Ghost/preview prop never appears -> `object_Model` path typo; nothing errors.
- Use prompt never appears on a custom class -> `EntityCommon.MakeUsable` overwrote your `IsUsable`.
- Game crashes on use -> `OnUsed` destroyed its own entity inline; defer a tick.

## See also

- War stories: custom-assets.md, blender-workspace.md, castle-model-review.md, gates.md, castle.md.
- Official wiki environment-art articles KM-A-44..54 (offline in `references/kcd2-mod-docs-main/official-wiki/`); see
  [sources.md](sources.md).
- [ui-scaleform.md](ui-scaleform.md) for UI textures, fonts and key-cap art.
