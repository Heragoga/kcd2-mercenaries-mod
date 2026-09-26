-- Castle builder: the palisade builder, drawing in stone.
--
-- It is not a second builder. `merc_castle_build` picks a stone wall type, arms the
-- corner towers and the back-face doubling, then starts the ordinary wall build mode,
-- so the runs it draws land in WallRuns like any other and the navmesh, the staged
-- battle, the raid checks and the defence save all keep working unchanged.
--
-- Three things stone needs that the palisade did not:
--   * a CHOICE of segment - the palisade had one mesh
--   * TOWERS on the corners - a stone curtain with square corners reads as a garden wall
--   * BACK FACES - a wall lifted off a fortress is a facade with a hollow back, so a run
--     of it is see-through from inside. Those types carry `back`, and each of their
--     segments is spawned twice - turned about and offset by CastleThick - which closes
--     the face and gives the wall its thickness. The free-standing types are modelled
--     both sides already and have it off.
--
-- Every `len` that is not stated by the mesh's own name is a GUESS. A .cgf carries no
-- usable bounding box, so a piece is sized by building with it: merc_castle_matrix to
-- see them all tiled side by side, merc_wall_len until the seam closes, merc_wall_up
-- until it sits on the ground, then merc_castle_tune to print the row. See docs/castle.md.

local FEN = "objects/manmade/structures/logistical/fences/"
local DEF = "objects/manmade/structures/defensive/"
local RUI = DEF .. "walls/wall_ruined/"
local SEG = DEF .. "walls/wall_segments/"
local MON = "objects/manmade/structures/theological/monasteries/unique/sedlec_monastery_dlc3/"
local SHR = "objects/manmade/structures/theological/shrines/"
local OWN = "objects/mercenaries/walls/"      -- our own assets (assets/blender)
local GAT = "objects/manmade/structures/logistical/gate/"
local ELM = "objects/intermediates/elements/"
local WAL = "objects/intermediates/walltool/"   -- the level designers' modular wall kit
local DOR = "objects/manmade/common_fixtures/doors/"

-- ==== wall segments ====
-- EVERY mesh below is a single object. That is not a style choice: most of what looks
-- like a castle wall in this game is one baked level section, and spawning it as a wall
-- segment tiles whole castles on top of each other. `suchdol_fortress_walls.cgf` carries
-- 32 nodes (arcades, bridge, gate, palace, two more wall runs, a tower);
-- `malesov_wall_01.cgf` carries 91, which is where the gatehouse and the broken gate in
-- it came from; `walls_semin.cgf` carries 205. A second trap sits behind that one: a
-- handful of single-object walls (Cimburk's ruins, the Opatovice parcel walls, the
-- Trosky gatehouse) are `physicalized_whitebox` blockout art with no texturing.
--
-- `tools/cgf_nodes.py --lua data/Scripts/mods/mercenaries_castle.lua` re-checks the
-- whole list against the paks and prints anything composite or whitebox. Run it before
-- adding a mesh here.
--
-- What survives that filter, by group:
--   castle  the ruined fortress pieces. The ONLY individual castle-height stone walls
--           in the game - every intact castle wall exists solely as baked fortress
--           geometry. piece_d ships full, half and quarter, so that set tiles.
--   low     low ruined town walls, waist to chest height.
--   fence   free-standing field walls. The only meshes whose names state their own
--           length, and `_noterrain` drops the strip of baked ground at the foot.
--   seg     wall_segment_220_60: 2.20m long, 0.60m thick, solid.
--
-- Lengths outside `fence` and `seg` are GUESSES - merc_castle_matrix, then merc_wall_len.
mercenaries.CastleWalls = {
    -- ours: built in Blender, compiled with the modding tools' rc.exe, textured with
    -- the base game's own stone. 4.00m long by design, so `len` is exact and a run
    -- tiles seamlessly, merlons included. Three variants so a long wall does not
    -- repeat: merc_castle_vary cycles them along the run.
    { n = "crenel",       grp = "custom", m = OWN .. "merc_castle_wall_a.cgf",
      mtl = OWN .. "merc_castle_stone",
      vary = { OWN .. "merc_castle_wall_a.cgf", OWN .. "merc_castle_wall_b.cgf",
               OWN .. "merc_castle_wall_c.cgf" },
      len = 4.00, up = 0.00, lat = 0, back = false, castle = true },
    { n = "crenel_a",     grp = "custom", m = OWN .. "merc_castle_wall_a.cgf",
      mtl = OWN .. "merc_castle_stone",
      len = 4.00, up = 0.00, lat = 0, back = false, castle = true },
    { n = "crenel_b",     grp = "custom", m = OWN .. "merc_castle_wall_b.cgf",
      mtl = OWN .. "merc_castle_stone",
      len = 4.00, up = 0.00, lat = 0, back = false, castle = true },
    { n = "crenel_c",     grp = "custom", m = OWN .. "merc_castle_wall_c.cgf",
      mtl = OWN .. "merc_castle_stone",
      len = 4.00, up = 0.00, lat = 0, back = false, castle = true },
    -- Hand-modelled in Blender and exported by assets/blender/export_wall.py: 10.08 m
    -- of wall, 7.35 m tall, its walk at 6.00 m. `len` is a centimetre SHORT of the mesh
    -- so consecutive pieces interpenetrate rather than meeting face to face - two bevelled
    -- ends butted together leave a hairline seam down every joint of the run.
    -- `decor` names a clutter list (data/Scripts/mods/prefabs/wall_<name>_decor.lua);
    -- the builder scatters a few of it on each segment.
    -- Three variants of the same mesh: identical geometry, but the vertex alpha that
    -- drives the blend layer is painted from a noise field that is reseeded AND rotated
    -- for each, so the weathering falls somewhere different every segment. They carry
    -- the same AMOUNT of it - a run where one length is visibly grubbier than the next
    -- reads as a mistake rather than as variety.
    { n = "crenel_hand",  grp = "custom", m = OWN .. "merc_castle_wall_hand_a.cgf",
      mtl = OWN .. "merc_castle_wall_hand",
      vary = { OWN .. "merc_castle_wall_hand_a.cgf", OWN .. "merc_castle_wall_hand_b.cgf",
               OWN .. "merc_castle_wall_hand_c.cgf" },
      decor = "crenel_hand", decorCount = 3,
      len = 10.07, up = 0.00, lat = 0, back = false, castle = true },
    -- Everything below is MEASURED off the mesh, not guessed: `len` is the 1st-to-99th
    -- percentile span of the vertices along the run, which is the tile pitch with the
    -- outlying rubble trimmed off, so pieces interpenetrate by a few centimetres rather
    -- than leaving a gap. `ox` is where the mesh's body sits along the run relative to
    -- its origin and `lat` is the same across it; both are subtracted at placement, so
    -- a piece modelled from one end (seg220, whitewash) still lands on its marker.
    -- `tall` is the height ABOVE the origin - these pieces bury 1.5-4.3m of foundation,
    -- so the bounding box is half again what you can actually stand behind.
    -- Re-measure with tools/measure_walls.py after touching any of it.
    --
    -- castle: ruined fortress walls, castle height
    { n = "ruin_a",       grp = "castle", m = RUI .. "ruined_fortress_wall_piece_a.cgf",        len =  9.72, tall = 11.32, deep =  3.50, up = 0.00, lat =  -0.00, ox =  -0.00, back = false, castle = true },
    { n = "ruin_b",       grp = "castle", m = RUI .. "ruined_fortress_wall_piece_b.cgf",        len =  4.64, tall =  8.65, deep =  3.40, up = 0.00, lat =  -0.01, ox =  0.07, back = false, castle = true },
    { n = "ruin_c",       grp = "castle", m = RUI .. "ruined_fortress_wall_piece_c.cgf",        len =  1.68, tall =  6.84, deep =  1.50, up = 0.00, lat = -0.01, ox =  0.28, back = false, castle = true },
    { n = "ruin_e",       grp = "castle", m = RUI .. "ruined_fortress_wall_piece_e.cgf",        len = 17.02, tall =  9.40, deep =  3.50, up = 0.00, lat = -0.02, ox = -0.04, back = false, castle = true },
    { n = "ruin_f",       grp = "castle", m = RUI .. "ruined_fortress_wall_piece_f.cgf",        len = 11.27, tall =  5.41, deep =  4.00, up = 0.00, lat =  1.16, ox = -0.15, back = false, castle = true },
    { n = "ruin_h",       grp = "castle", m = RUI .. "ruined_fortress_wall_piece_h.cgf",        len =  5.21, tall =  8.00, deep =  4.30, up = 0.00, lat = -0.10, ox =  0.07, back = false, castle = true },
    { n = "ruin_h_flip",  grp = "castle", m = RUI .. "ruined_fortress_wall_piece_h_flipped.cgf",len =  5.21, tall =  8.00, deep =  4.30, up = 0.00, lat = -0.10, ox = -0.05, back = false, castle = true },
    { n = "ruin_i",       grp = "castle", m = RUI .. "ruined_fortress_wall_piece_i.cgf",        len =  9.01, tall = 10.16, deep =  4.10, up = 0.00, lat = -0.00, ox = -0.11, back = false, castle = true },
    { n = "ruin_k",       grp = "castle", m = RUI .. "ruined_fortress_wall_piece_k.cgf",        len =  9.19, tall = 12.13, deep =  3.60, up = 0.00, lat =  0.02, ox =  0.06, back = false, castle = true },
    -- Not curtains. The piece_d set is a FOUNDATION - 1.5m tall and 6.7m deep, a
    -- footprint lying on the ground. g/j/l are corner-and-tower chunks 12-15m deep,
    -- beam_a/b are loose timbers, and suchdol_dmg is 26m of palace whose long axis is
    -- not even its X. They scatter as rubble; they never tile as a wall.
    { n = "ruin_d",       grp = "rubble", m = RUI .. "ruined_fortress_wall_piece_d.cgf",        len =  8.55, tall =  1.52, deep =  0.00, up = 0.00, lat =  0.11, ox = -0.07, back = false, castle = true },
    { n = "ruin_d_half_a",grp = "rubble", m = RUI .. "ruined_fortress_wall_piece_d_half_a.cgf", len =  4.47, tall =  1.52, deep =  0.00, up = 0.00, lat = 0.19, ox = -2.26, back = false, castle = true },
    { n = "ruin_d_half_b",grp = "rubble", m = RUI .. "ruined_fortress_wall_piece_d_half_b.cgf", len =  4.69, tall =  1.46, deep =  0.00, up = 0.00, lat =  0.05, ox = 2.06, back = false, castle = true },
    { n = "ruin_d_qtr",   grp = "rubble", m = RUI .. "ruined_fortress_wall_piece_d_quater.cgf", len =  4.74, tall =  1.45, deep =  0.00, up = 0.00, lat = 1.21, ox = 2.15, back = false, castle = true },
    { n = "ruin_g",       grp = "rubble", m = RUI .. "ruined_fortress_wall_piece_g.cgf",        len = 15.22, tall = 9.38, deep =  3.70, up = 0.00, lat = -0.45, ox = -0.21, back = false, castle = true },
    { n = "ruin_j",       grp = "rubble", m = RUI .. "ruined_fortress_wall_piece_j.cgf",        len = 9.70, tall = 16.23, deep =  1.60, up = 0.00, lat = 2.55, ox = 0.05, back = false, castle = true },
    { n = "ruin_l",       grp = "rubble", m = RUI .. "ruined_fortress_wall_piece_l.cgf",        len = 20.00, tall = 12.40, deep =  3.60, up = 0.00, lat =  -0.09, ox = 0.18, back = false, castle = true },
    { n = "beam_a",       grp = "rubble", m = RUI .. "ruined_fortress_wall_brokenbeam_a.cgf",   len =  2.16, tall =  0.24, deep =  0.00, up = 0.00, lat = -0.00, ox = -0.77, back = false, castle = true },
    { n = "beam_b",       grp = "rubble", m = RUI .. "ruined_fortress_wall_brokenbeam_b.cgf",   len =  0.39, tall =  0.57, deep =  0.00, up = 0.00, lat = 0.05, ox =  0.00, back = false, castle = true },
    { n = "ruin_house",   grp = "rubble", m = RUI .. "wall_ruined_piece_a.cgf",                 len =  6.39, tall =  1.50, deep =  2.70, up = 0.00, lat = -0.04, ox = -0.06, back = false, castle = true },
    { n = "suchdol_dmg",  grp = "rubble", m = DEF .. "fortress/suchdol/suchdol_palace_wall_part_damaged.cgf", len = 3.75, tall = 25.92, deep =  0.00, up = 0.00, lat = -13.10, ox = 19.03, back = false, castle = true },
    -- intact, and low enough to look like an enclosure rather than a ruin
    { n = "whitewash",    grp = "castle", m = DEF .. "walls/wall_rough_whitewashed/wall_rough_whitewashed_piece_a.cgf", len = 4.63, tall = 1.35, deep =  0.00, up = 0.00, lat = -0.05, ox = 2.36, back = false, castle = true },
    -- low: ruined town walls, waist to chest
    { n = "low_a",        grp = "low", m = RUI .. "wall_low_ruined_kh_a.cgf",        len = 3.12, tall = 0.98, deep =  0.00, up = 0.00, lat = -0.01, ox = -0.00, back = false, castle = true },
    { n = "low_a_dark",   grp = "low", m = RUI .. "wall_low_ruined_kh_a_dark.cgf",   len = 3.12, tall = 0.98, deep =  0.00, up = 0.00, lat = -0.02, ox = -0.02, back = false, castle = true },
    { n = "low_b",        grp = "low", m = RUI .. "wall_low_ruined_kh_b.cgf",        len = 3.10, tall = 0.84, deep =  0.00, up = 0.00, lat = -0.00, ox = -0.01, back = false, castle = true },
    { n = "low_b_dark",   grp = "low", m = RUI .. "wall_low_ruined_kh_b_dark.cgf",   len = 3.10, tall = 0.84, deep =  0.00, up = 0.00, lat = -0.01, ox = -0.02, back = false, castle = true },
    { n = "low_c",        grp = "low", m = RUI .. "wall_low_ruined_kh_c.cgf",        len = 3.11, tall = 0.81, deep =  0.00, up = 0.00, lat =  0.02, ox = 0.00, back = false, castle = true },
    { n = "low_c_dark",   grp = "low", m = RUI .. "wall_low_ruined_kh_c_dark.cgf",   len = 3.11, tall = 0.81, deep =  0.00, up = 0.00, lat = 0.04, ox = -0.04, back = false, castle = true },
    { n = "low_d",        grp = "low", m = RUI .. "wall_low_ruined_kh_d.cgf",        len = 3.01, tall = 0.70, deep =  0.00, up = 0.00, lat = -0.00, ox = 0.04, back = false, castle = true },
    { n = "low_d_dark",   grp = "low", m = RUI .. "wall_low_ruined_kh_d_dark.cgf",   len = 3.01, tall = 0.70, deep =  0.00, up = 0.00, lat = -0.00, ox = -0.03, back = false, castle = true },
    -- fence: free-standing field walls, modelled both sides. The NAME is neither the
    -- length nor the height: "5m" tiles at 5.12 and stands 1.74m proud, the other 2.45m
    -- being buried foundation. The `_crop` pair is the same wall with its top shaved.
    { n = "fence5",       grp = "fence", m = FEN .. "stone_fence_5m_noterrain.cgf",          len =  5.12, tall = 1.74, deep =  2.50, up = 0.00, lat =  0.09, ox = -0.11, back = false, castle = true },
    { n = "fence5_b",     grp = "fence", m = FEN .. "stone_fence_5m_noterrain_b.cgf",        len =  5.13, tall = 1.71, deep =  2.50, up = 0.00, lat =  0.09, ox = -0.11, back = false, castle = true },
    { n = "fence5_crop",  grp = "fence", m = FEN .. "stone_fence_5m_noterrain_cropped.cgf",  len =  5.22, tall = 1.74, deep =  0.00, up = 0.00, lat =  0.08, ox = -0.12, back = false, castle = true },
    { n = "fence16",      grp = "fence", m = FEN .. "stone_fence_16m_noterrain.cgf",         len = 16.76, tall = 1.80, deep =  2.50, up = 0.00, lat =  0.18, ox = -0.38, back = false, castle = true },
    { n = "fence16_b",    grp = "fence", m = FEN .. "stone_fence_16m_noterrain_b.cgf",       len = 16.78, tall = 1.80, deep =  2.50, up = 0.00, lat =  0.20, ox = -0.40, back = false, castle = true },
    { n = "fence16_crop", grp = "fence", m = FEN .. "stone_fence_16m_noterrain_cropped.cgf", len = 16.45, tall = 1.92, deep =  0.00, up = 0.00, lat =  0.19, ox = -0.38, back = false, castle = true },
    -- kh: the KUTTENBERG WALLTOOL KIT - the level designers' own modular city wall, and
    -- the best base-game answer to "a wall you can defend". Three families, every piece
    -- one node, all fully textured:
    --
    --   kh_*        the city wall proper. 12.2m tiles, 2.5m thick, 10.2m to the top of
    --               its roofed hoarding, and a real WALL-WALK at 8.00m - 24 m2 of deck
    --               per tile. Five variants plus a weathered `_wet` set.
    --   kh02_*      the thinner second wall: 10.0m tiles, 8.2m tall, walk at 6.00m.
    --   khstone_*   the town's property wall: 4.3m tiles, 0.7m thick, 3.6m tall, and a
    --               plastered colourway. Not defensible - a yard wall, and it reads as
    --               one.
    --
    -- The whole kit runs along the mesh's own +Y, hence `yaw = -90`, and every piece is
    -- modelled from one END rather than about its middle, hence the large `ox`.
    --
    -- The city wall ships no transition piece, so it has generated ones: the same mesh
    -- ROTATED 12 degrees along its run, which lifts it 2.06 m across its own 12.39 m
    -- tile. Rotated, not sheared - a shear lifts the wall but leaves every merlon bolt
    -- upright, and the merlons have to rake with the wall or it reads as a staircase.
    -- Two thirds of the tile is at a constant lean; only the ends taper back to vertical
    -- so they still mate with a level neighbour. See assets/gen_wall_pieces.py.
    -- `mid` is the one wired here; `ramp`, `in` and `out` are built for a continuous
    -- slope and are not yet chosen between.
    --
    -- `up = -3.00` on the two city walls is deliberate: 10.2 m is right for a city and
    -- too much for a camp, so they are sunk three metres into their own foundation.
    -- That leaves 7.2 m standing with the walk at 5.00 m, and costs nothing - the mesh
    -- carries 4.9 m of buried footing, so there is still 1.9 m of it below ground.
    -- merc_wall_up puts it back.
    --
    -- It also ships `_left_90`/`_right_90` corners, `_end_a`, `_start`, `_gate_a/b/c`,
    -- `_doorway` and `_up`/`_down` slope pieces. Nothing else in the game has a corner
    -- mesh for BOTH hands, so this is the only family that could close a right turn
    -- without a tower. None of that is wired up yet - see docs/castle.md.
    { n = "kh_a",         grp = "kh", m = WAL .. "wall_kh_a.cgf",                     len = 12.39, tall = 10.20, deep =  4.90, walk = 8.00, up = -3.00, lat = -0.15, ox = 6.20, yaw = -90, back = false, castle = true },
    { n = "kh_b",         grp = "kh", m = WAL .. "wall_kh_b.cgf",                     len = 12.39, tall = 10.14, deep =  4.90, walk = 8.00, up = -3.00, lat = -0.15, ox = 6.21, yaw = -90, back = false, castle = true },
    { n = "kh_c",         grp = "kh", m = WAL .. "wall_kh_c.cgf",                     len = 12.39, tall = 10.10, deep =  4.90, walk = 8.00, up = -3.00, lat = -0.15, ox = 6.20, yaw = -90, back = false, castle = true },
    { n = "kh_d",         grp = "kh", m = WAL .. "wall_kh_d.cgf",                     len = 12.39, tall = 10.09, deep =  4.90, walk = 8.00, up = -3.00, lat = -0.15, ox = 6.20, yaw = -90, back = false, castle = true },
    { n = "kh_e",         grp = "kh", m = WAL .. "wall_kh_e.cgf",                     len = 12.39, tall = 10.20, deep =  4.90, walk = 8.00, up = -3.00, lat = -0.15, ox = 6.21, yaw = -90, back = false, castle = true },
    { n = "kh_a_wet",     grp = "kh", m = WAL .. "wall_kh_a_wet.cgf",                 len = 12.39, tall = 10.20, deep =  4.90, walk = 8.00, up = -3.00, lat = -0.15, ox = 6.20, yaw = -90, back = false, castle = true },
    { n = "kh_b_wet",     grp = "kh", m = WAL .. "wall_kh_b_wet.cgf",                 len = 12.39, tall = 10.14, deep =  4.90, walk = 8.00, up = -3.00, lat = -0.15, ox = 6.21, yaw = -90, back = false, castle = true },
    { n = "kh_c_wet",     grp = "kh", m = WAL .. "wall_kh_c_wet.cgf",                 len = 12.39, tall = 10.10, deep =  4.90, walk = 8.00, up = -3.00, lat = -0.14, ox = 6.20, yaw = -90, back = false, castle = true },
    { n = "kh_d_wet",     grp = "kh", m = WAL .. "wall_kh_d_wet.cgf",                 len = 12.41, tall = 10.09, deep =  4.90, walk = 8.00, up = -3.00, lat = -0.15, ox = 6.20, yaw = -90, back = false, castle = true },
    { n = "kh_e_wet",     grp = "kh", m = WAL .. "wall_kh_e_wet.cgf",                 len = 12.39, tall = 10.20, deep =  4.90, walk = 8.00, up = -3.00, lat = -0.15, ox = 6.21, yaw = -90, back = false, castle = true },
    { n = "kh02_a",       grp = "kh", m = WAL .. "wall_kh_02_a.cgf",                  len =  10.00, tall =  8.26, deep =  4.90, walk = 6.00, up = -3.00, lat =  -0.12, ox = 5.00, yaw = -90, back = false, castle = true },
    { n = "kh02_b",       grp = "kh", m = WAL .. "wall_kh_02_b.cgf",                  len =  10.00, tall =  8.18, deep =  4.90, walk = 5.90, up = -3.00, lat =  -0.12, ox = 5.00, yaw = -90, back = false, castle = true },
    { n = "kh02_drain",   grp = "kh", m = WAL .. "wall_kh_02_drain.cgf",              len =   10.00, tall =  8.25, deep =  5.40, walk = 5.90, up = -3.00, lat = -0.12, ox = 5.00, yaw = -90, back = false, castle = true },
    -- The yard wall is the ONLY family in the kit with transition pieces: `_up` lifts
    -- its crest 1.40 m across one tile and `_down` drops it 1.37 m, so a run of it walks
    -- a slope in steps instead of being laid flat and letting the terrain swallow the
    -- difference. The city wall ships none - there is no wall_kh_up or wall_kh_down in
    -- the paks - so it keeps the levelling rule, which has 7.9 m of buried footing to
    -- absorb a fall before any daylight shows under it.
    { n = "khstone_a",    grp = "kh", m = WAL .. "stone_wall_kh_normal.cgf",          len =  4.31, tall =  3.58, deep =  0.00, up = 0.00, lat =  0.00, ox = 2.13, yaw = -90, back = false, castle = true,
      slope = { start = 0.70,
        up   = { step = { m = WAL .. "stone_wall_kh_up.cgf",   rise =  1.402 } },
        down = { step = { m = WAL .. "stone_wall_kh_down.cgf", rise = -1.373 } } } },
    { n = "khstone_b",    grp = "kh", m = WAL .. "stone_wall_kh_normal_b.cgf",        len =  4.31, tall =  3.62, deep =  0.00, up = 0.00, lat =  -0.01, ox = 2.14, yaw = -90, back = false, castle = true,
      slope = { start = 0.70,
        up   = { step = { m = WAL .. "stone_wall_kh_up.cgf",   rise =  1.402 } },
        down = { step = { m = WAL .. "stone_wall_kh_down.cgf", rise = -1.373 } } } },
    { n = "khplaster_a",  grp = "kh", m = WAL .. "stone_wall_kh_plaster_normal.cgf",  len =  4.31, tall =  3.58, deep =  0.00, up = 0.00, lat =  0.00, ox = 2.12, yaw = -90, back = false, castle = true,
      slope = { start = 0.70,
        up   = { step = { m = WAL .. "stone_wall_kh_plaster_up.cgf",   rise =  1.402 } },
        down = { step = { m = WAL .. "stone_wall_kh_plaster_down.cgf", rise = -1.373 } } } },
    { n = "khplaster_b",  grp = "kh", m = WAL .. "stone_wall_kh_plaster_normal_b.cgf",len =  4.31, tall =  3.62, deep =  0.00, up = 0.00, lat =  -0.01, ox = 2.13, yaw = -90, back = false, castle = true,
      slope = { start = 0.70,
        up   = { step = { m = WAL .. "stone_wall_kh_plaster_up.cgf",   rise =  1.402 } },
        down = { step = { m = WAL .. "stone_wall_kh_plaster_down.cgf", rise = -1.373 } } } },
    -- seg: the name says 220x60, the mesh tiles at 5.05 and stands 2.30 tall. Its origin
    -- is at one END, not its middle, which is what `ox` is for.
    { n = "seg220_a",     grp = "seg", m = SEG .. "wall_segment_220_60_a_a.cgf", len = 5.05, tall = 2.30, deep =  0.00, up = 0.00, lat = 0.03, ox = 2.50, back = false, castle = true },
    { n = "seg220_b",     grp = "seg", m = SEG .. "wall_segment_220_60_a_b.cgf", len = 5.09, tall = 2.34, deep =  0.00, up = 0.00, lat = 0.06, ox = 2.49, back = false, castle = true },
    { n = "seg220_c",     grp = "seg", m = SEG .. "wall_segment_220_60_a_c.cgf", len = 2.06, tall = 2.26, deep =  0.00, up = 0.00, lat = 0.04, ox = 1.02, back = false, castle = true },
}

-- The dozen worth actually looking at, in the order merc_castle_rects builds them: the
-- Kuttenberg walltool kit, which is the only base-game family that is INTACT, tiles on a
-- known pitch, and carries a real wall-walk. Six of the city wall, two of the thinner
-- second wall, and four of the town's yard wall for scale.
-- `merc_castle_rects castle` still builds the ruined fortress pieces.
mercenaries.CastleRectPicks = {
    "kh_a", "kh_b", "kh_c", "kh_d", "kh_e", "kh_a_wet",
    "kh02_a", "kh02_b",
    "khstone_a", "khstone_b", "khplaster_a", "khplaster_b",
}

-- Only our own pieces have corners cut for them. They are the only ones built on a
-- known tile (4.00m) and a known merlon grid (1.00m), which is what a corner mesh has
-- to continue; a base-game wall of a guessed length has nothing to line up with, so
-- its turns are closed by a tower as they always were.
for _, t in ipairs(mercenaries.CastleWalls) do
    if t.grp == "custom" then
        t.towerkit = true
        -- Measured centre of the unobstructed walking strip, in mesh-local Y.
        t.walkcenter = (t.n == "crenel_hand") and 0.35 or 0.10
        t.corners = (t.n ~= "crenel_hand")
        t.walkheight = (t.n == "crenel_hand") and 6.00 or 4.90
    end
end

-- ==== corner towers ====
-- Same rule, and it bites hardest here: there is NO individual castle tower in the game.
-- watchtower_a is 54 nodes, bastion_kh_01 is 127, malesov_wall_tower is 168 - each is a
-- slice of its castle, not a prop. What is left is pillars: the fence family's own
-- (which match its wall), the Sedlec monastery buttress pillars, and the roadside
-- devotional pillars. They read as a corner post, not as a turret.
mercenaries.CastleTowers = {
    { n = "none",        m = nil },
    -- Ours, and the only one the wall makes room for. `cut` is how much of the run it
    -- stands in for - half a segment either side of the corner, the same bite the corner
    -- pieces take - and `lat` steps it inboard onto the wall walk's centre line, which
    -- is where its doorways are, so the walk runs straight in one side and out the
    -- other. `wallup` keeps it level with the walls when they are raised or sunk.
    { n = "crenel_a",    m = OWN .. "merc_castle_tower_a.cgf",
                         mtl = OWN .. "merc_castle_stone",                 up = 0.00,
                         cut = 4.00, lat = 0.25, wallup = true, door = true,
                         rearBlind = true, doorOffset = 1.82,
                         tall = OWN .. "merc_castle_tower_hand.cgf" },
    -- the stone_fence pillars carry a baked grass and terrain skirt, so away from the
    -- ground they plant a heap of dirt at every corner
    -- The Kuttenberg wall's own bastion, in the two colourways that looked right. It is
    -- self-contained: walls, three platforms, stairs and roof, no castle attached. Its
    -- lowest platform is at 5.00m - which is exactly where the city wall's walk ends up
    -- once that wall is sunk its 3m, so the two meet with the bastion sitting on the
    -- ground and no offset at all. 4.8m half-width, hence the 4.80 cut.
    -- (Measured on the render mesh only: counting the shadow proxy invents a platform at
    -- 8m that nothing can stand on.)
    { n = "bastion_w",   m = "objects/manmade/structures/defensive/walls/unique/kutna_hora/bastion_kh_01_white.cgf",
                         up = 0.00, cut = 4.80, wallup = true },
    { n = "bastion_03",  m = "objects/manmade/structures/defensive/walls/unique/kutna_hora/bastion_kh_03.cgf",
                         up = 0.00, cut = 4.80, wallup = true },
    { n = "pillar",      m = FEN .. "stone_fence_pillar.cgf",              up = 0.00 },
    { n = "pillar_b",    m = FEN .. "stone_fence_pillar_b.cgf",            up = 0.00 },
    { n = "mon_b",       m = MON .. "monastery_pillar_out_b.cgf",          up = 0.00 },
    { n = "mon_b2",      m = MON .. "monastery_pillar_out_b2.cgf",         up = 0.00 },
    { n = "mon_high",    m = MON .. "monastery_pillar_out_high_1.cgf",     up = 0.00 },
    { n = "mon_wide_d",  m = MON .. "monastery_pillar_out_wide_d.cgf",     up = 0.00 },
    { n = "mon_wide_e",  m = MON .. "monastery_pillar_out_wide_e.cgf",     up = 0.00 },
    { n = "sedlec_col",  m = MON .. "sedlec_column_plain.cgf",             up = 0.00 },
    { n = "sedlec_twr",  m = MON .. "sedlec_cathedral_ext_tower_a.cgf",    up = 0.00 },
    { n = "devotional",  m = SHR .. "devotional_pillar_01.cgf",            up = 0.00 },
    { n = "devotional3", m = SHR .. "devotional_pillar_03.cgf",            up = 0.00 },
    { n = "devotional5", m = SHR .. "devotional_pillar_05.cgf",            up = 0.00 },
    { n = "rock_column", m = "objects/manmade/structures/industrial/mines/rock/limestone_mine_rock_column_a.cgf", up = 0.00 },
}

-- ==== tower candidates, for looking at ====
-- Not a pick list - a survey. Every tower-ish mesh in the paks that is a standalone prop
-- rather than a slice of a castle, with the two figures that decide whether it can stand
-- on a curtain: `half`, the footprint the wall has to stop short of, and `decks`, every
-- floor in it with real area. merc_castle_tower_row stands each one up with the current
-- wall running into it, picking whichever deck is nearest that wall's own walk and
-- sinking or raising the tower to put the two level. Measured off the meshes.
-- The husova pair are ROUND towers and they render wrong out of the box: the shipped
-- walls.mtl points its `beams` slot at objects/plankomatic/textures/, but those textures
-- ship under objects/INTERMEDIATES/plankomatic/, and its `wall_stones_decals` slot names
-- a texture that is in none of the 42 paks. merc_husova_walls.mtl is that file with both
-- paths repaired, all nine submaterials kept in their original order - a replacement with
-- fewer would hide submeshes outright.
local TW = "objects/manmade/structures/"
mercenaries.CastleTowerSurvey = {    { n = "bastion_kh",     m = TW .. "defensive/walls/unique/kutna_hora/bastion_kh_01.cgf",            half =  4.8, tall = 23.41, decks = { 5.00, 11.75, 13.75 } },
    { n = "bastion_kh_w",   m = TW .. "defensive/walls/unique/kutna_hora/bastion_kh_01_white.cgf",      half =  4.8, tall = 23.41, decks = { 5.00, 11.75, 13.75 } },
    { n = "bastion_kh_03",  m = TW .. "defensive/walls/unique/kutna_hora/bastion_kh_03.cgf",            half =  4.8, tall = 23.41, decks = { 5.00, 8.00, 11.00, 13.75, 15.25 } },
    { n = "husova",         m = TW .. "living/houses/unique/kutna_hora/husova/walls/tower.cgf",         mtl = OWN .. "merc_husova_walls", half =  4.9, tall = 24.55, decks = { 14.25 } },
    { n = "husova_b",       m = TW .. "living/houses/unique/kutna_hora/husova/walls/tower_b.cgf",       mtl = OWN .. "merc_husova_walls", half =  4.2, tall = 23.12, decks = { 9.50, 12.25 } },
    { n = "ratibor",        m = TW .. "defensive/fortress/ratibor/ratibor_tower.cgf",                   half =  4.5, tall = 11.51, decks = { 2.25 } },
    { n = "malesov_round",  m = TW .. "defensive/fortress/malesov/malesov_round_tower.cgf",             half =  4.2, tall = 11.84, decks = { 2.50, 5.25 } },
    { n = "malesov_wall",   m = TW .. "defensive/fortress/malesov/malesov_wall_tower.cgf",              half =  5.7, tall = 14.61, decks = { 4.00 } },
    { n = "monastery_a",    m = TW .. "theological/monasteries/unique/sedlcko/monastery_tower_a.cgf",   half =  2.5, tall = 11.99, decks = { 5.50 } },
    { n = "watchtower_a",   m = TW .. "defensive/watchtowers/watchtower_a.cgf",                         half =  2.8, tall =  9.26, decks = { 3.25 } },
    { n = "nebakov",        m = TW .. "defensive/watchtowers/unique/nebakov/watchtower.cgf",            half =  4.2, tall =  9.68, decks = { 3.00 } },
    { n = "trosky_guard",   m = TW .. "defensive/castles/unique/trosky/trosky_5_guardtower.cgf",        half =  8.2, tall = 13.12, decks = { 1.75, 4.50, 7.00 } },
}

-- ==== gates ====
-- Appended to GateStyles, so hanging one uses the ordinary gate machinery (E prompt,
-- open/shut, sentries, raid suppression). `frame` is a static piece that is never
-- swapped: a stone arch stands whether the gate is open or shut, and only the colliders
-- and the pathing know the difference.
--
-- ratibor_gate is the only stone gate in the game that is one object. Every city gate
-- and gatehouse is its whole gate complex (gate_kh_01 is 187 nodes, gate_malesov 164),
-- and gate_kh_02, which IS one object, is untextured whitebox. So the rest of this list
-- is the small multi-part gates - five or six nodes, which is a gate with its own frame
-- and decals rather than a slice of castle. The Nebakov pair is the only castle gate
-- with leaves carved open and shut, so it is the only one that visibly swings.
mercenaries.CastleGates = {
    { n = "ratibor",     frame = DEF .. "fortress/ratibor/ratibor_gate.cgf",        width = 5.0 },
    { n = "castle_b",    frame = ELM .. "gate_castle_b.cgf",                        width = 4.0 },
    { n = "castle_e",    frame = ELM .. "gate_castle_e.cgf",                        width = 4.0 },
    { n = "plaster",     frame = GAT .. "gate_plaster_b.cgf",                       width = 4.0 },
    { n = "zidovska",    frame = GAT .. "unique/gate_zidovska_05.cgf",              width = 4.0 },
    { n = "nebakov",     open = DEF .. "gatehouses/unique/nebakov/gate_nebakov_opened.cgf",
                         closed = DEF .. "gatehouses/unique/nebakov/gate_nebakov.cgf", width = 4.0 },
}

-- The Kuttenberg city wall. It is the default because it is the only base-game
-- curtain that is intact, tiles on a pitch it was designed for, carries a real
-- wall-walk, and owns a corner piece for both hands - so merc_castle_square
-- closes on itself with no seam and no tower standing in for a corner.
mercenaries.CastleWallIdx  = 41   -- kh_a
mercenaries.CastleTowerIdx = 2      -- our own tower
mercenaries.CastleTowersOn = true
mercenaries.CastleTowerEnds = true  -- towers on the open ends of a run, not just its corners
mercenaries.CastleTowerUp  = nil    -- nil = the tower's own tuned offset
mercenaries.CastleTowerYaw = 0
-- Offset of the doubled-back copy, in metres. This is the wall's thickness as well as
-- the fix for the see-through face; 0 turns the doubling off. Negative puts the copy on
-- the other side, which is what to try if the wall reads as thick on the wrong face.
mercenaries.CastleThick    = 0.60

-- Where the castle wall types start in WallTypes. Appended, never inserted, so the
-- palisade indices (and every QMWallType already written into a save) still mean what
-- they meant.
mercenaries.CastleWallBase  = 0
mercenaries.CastleGateBase  = 0

local function cLog(msg) System.LogAlways("[Castle] " .. tostring(msg)) end

local function castleArg(v)
    local t = tostring(v or ""):gsub("^%s*(.-)%s*$", "%1")
    t = t:gsub('^"(.*)"$', "%1"):gsub("^'(.*)'$", "%1")
    return (t:gsub("^%s*(.-)%s*$", "%1"))
end

local function wrapDeg(a)
    while a <= -180 do a = a + 360 end
    while a > 180 do a = a - 360 end
    return a
end

-- How far the run bends at vertex i, in degrees, POSITIVE TO THE LEFT, plus the yaw it
-- came in on. nil at a straight-through mark and at the ends of an open run, which are
-- not turns at all.
local TURN_MIN = 8      -- degrees; below this the run is going straight on

local function turnAt(r, i)
    local m, n = r.pts, #r.pts
    if n < 3 then return nil end
    if not r.closed and (i == 1 or i == n) then return nil end
    local prev, nxt = m[(i - 2) % n + 1], m[i % n + 1]
    local ain  = math.atan2(m[i].y - prev.y, m[i].x - prev.x)
    local aout = math.atan2(nxt.y - m[i].y, nxt.x - m[i].x)
    local turn = wrapDeg(math.deg(aout - ain))
    if math.abs(turn) < TURN_MIN then return nil end
    return turn, ain
end

-- Register the wall types and the gate styles once, at load.
do
    mercenaries.CastleWallBase = #mercenaries.WallTypes
    for _, t in ipairs(mercenaries.CastleWalls) do
        table.insert(mercenaries.WallTypes, t)
    end
    if mercenaries.GateStyles then
        mercenaries.CastleGateBase = #mercenaries.GateStyles
        for _, g in ipairs(mercenaries.CastleGates) do
            table.insert(mercenaries.GateStyles, g)
        end
    end
end

function mercenaries:CastleWallType()
    return self.WallTypes[self.CastleWallBase + self.CastleWallIdx]
end

function mercenaries:CastleTowerSpec()
    return self.CastleTowers[self.CastleTowerIdx] or self.CastleTowers[1]
end

-- ==== back faces ====
-- Called from WallSpawnSegment once the piece is up. The copy is turned about and
-- pushed along the segment's own left, so the two meshes present a face each way and
-- the gap between them is the wall's thickness. Re-entrant: the copy must not spawn a
-- copy of itself.
function mercenaries:CastleSpawnBack(pos, yaw)
    if self._castleBacking then return end
    local t = self.WallTypes[self.WallTypeIdx]
    if not (t and t.back) then return end
    local d = tonumber(self.CastleThick) or 0
    if d == 0 then return end
    self._castleBacking = true
    pcall(function()
        self:WallSpawnSegment({ x = pos.x - math.sin(yaw) * d,
                                y = pos.y + math.cos(yaw) * d,
                                z = pos.z }, yaw + math.pi)
    end)
    self._castleBacking = nil
end

-- ==== what stands on a corner ====
-- A turn in a stone curtain is a piece of masonry, not a mitre. Two straight segments
-- meeting at an angle leave a wedge open on the OUTER face - the wider the turn the
-- wider the wedge - which is what the palisade's corner posts were papering over. The
-- corner meshes are the real thing: two 2.00m stubs of the same cross-section meeting
-- at the turn, with a quoined arris up the outside.
--
-- 2.00m is half a segment ON PURPOSE. A corner eats exactly one 4.00m tile out of the
-- run, so what is left of each edge is still a whole number of segments and the 1.00m
-- merlon grid runs straight through the turn. That is the whole reason the walls step
-- back for these instead of the pieces being dropped on top of them.
--
-- The mesh IS the turn, and it is built for a LEFT one: the battlements are on the
-- right of the direction of travel, so an enclosure is walked anticlockwise and every
-- corner of it turns left (CastleFixWinding sees to that). A right turn - the notch of
-- a re-entrant corner - has its outer faces on the inside of the bend where the two
-- runs already overlap, so it needs no piece; it takes a tower if towers are on.
mercenaries.CastleCornerArm = 2.00
mercenaries.CastleCornersOn = true
mercenaries.CastleCorners = {
    { turn =  45, m = OWN .. "merc_castle_corner_45.cgf",  mtl = OWN .. "merc_castle_stone" },
    { turn =  90, m = OWN .. "merc_castle_corner_90.cgf",  mtl = OWN .. "merc_castle_stone" },
    { turn = 135, m = OWN .. "merc_castle_corner_135.cgf", mtl = OWN .. "merc_castle_stone", cut = 3.00 },
}

-- The walltool kit's own corners, and the only pair in the game cut for BOTH hands - so
-- these are the only wall type whose right turns do not have to fall back to a tower.
--
-- Three things they need that ours do not. They run along the mesh's +Y like the rest of
-- the kit, hence `yaw`. Their turn happens at a point well inside the mesh rather than at
-- its origin, so `px`/`py` name that point and the builder offsets the piece to stand it
-- on the marked corner. And they are NOT symmetric about it: each eats more of the edge
-- it receives than of the one it hands on, hence `cutIn`/`cutOut` instead of one `cut`.
-- All four figures are measured - see tools/measure_walls.py and docs/castle.md.
-- Everything here is measured on the arms' END FACES, because that is what the pieces
-- were built to share: the corner's incoming face is x -1.6016..1.2959, which is the
-- straight's face to the last decimal. Aligning on the arms' middles instead misses by
-- 0.30 m - the arms TAPER, so their middles do not match the straight's middle even
-- though their ends do, and the wall ends up standing proud of its own corner. That is
-- not a gap and not a height difference, just a step in the face at every turn. Measuring the arms off their outermost geometry instead
-- takes in the overhang, which juts past the body at every end, and puts a 2 cm seam at
-- every corner. Floored, so the curtain runs into the corner rather than stopping short.
-- The city wall's generated slope set. A lean is ENTERED, HELD for as many tiles as the
-- ground needs, and LEFT - so a long climb is one continuous 12-degree incline instead of
-- a staircase of single-tile steps. The three pieces chain because their end faces agree:
-- `enter` runs 0 to 12 degrees, `hold` 12 to 12, `leave` 12 back to 0, and a level
-- straight is 0. Each carries its own rise, because they are not the same length of lean.
--
-- The tilted faces overhang their tile - the top of a leaning wall leans past its own
-- footprint - but the next piece leans the same way, so they interlock rather than
-- collide, and the spacing along the ground is still one tile. Generated by
-- assets/gen_wall_pieces.py; see docs/castle.md.
mercenaries.KHSlope = {
    start = 1.00,       -- how far the ground must pull away before a lean is worth it
    up = {
        enter = { m = OWN .. "merc_kh_slope_in_up.cgf",   rise =  1.01 },
        hold  = { m = OWN .. "merc_kh_slope_ramp_up.cgf", rise =  2.62 },
        leave = { m = OWN .. "merc_kh_slope_out_up.cgf",  rise =  1.06 },
    },
    down = {
        enter = { m = OWN .. "merc_kh_slope_in_down.cgf",   rise = -1.07 },
        hold  = { m = OWN .. "merc_kh_slope_ramp_down.cgf", rise = -2.64 },
        leave = { m = OWN .. "merc_kh_slope_out_down.cgf",  rise = -1.02 },
    },
}

mercenaries.CastleCornersKH = {
    { turn =  90, m = WAL .. "wall_kh_left_90.cgf",  yaw = -90,
      px = -0.15, py = 5.09, cutIn = 5.09, cutOut = 3.89 },
    { turn = -90, m = WAL .. "wall_kh_right_90.cgf", yaw = -90,
      px = -0.15, py = 5.39, cutIn = 5.39, cutOut = 3.38 },
    -- Gentle turns, and these are not corner meshes at all: they are the STRAIGHT piece
    -- bent into a circular arc (assets/gen_wall_pieces.py). Every cross-section is
    -- rotated as a rigid body about one vertical axis, so both end faces keep exactly
    -- the profile the straights share - which is why this works where rebending the
    -- 90-degree corners did not. A corner's angle lives in its mitre, and changing it
    -- there needs material added or taken away; a straight has no mitre to fight.
    --
    -- An arc is symmetric, so cutIn and cutOut are equal - unlike the kit's own corners -
    -- and both are simply where the end tangents cross: radius * tan(turn/2). `px` falls
    -- on the straight's own lane, so the joint is flush by construction rather than by
    -- fitting. Radii are 47 m, 24 m and 16 m.
    { turn =  15, m = OWN .. "merc_kh_bend_left_15.cgf",  yaw = -90,
      px = -0.15, py = 6.24, cutIn = 6.24, cutOut = 6.24 },
    { turn = -15, m = OWN .. "merc_kh_bend_right_15.cgf", yaw = -90,
      px = -0.15, py = 6.24, cutIn = 6.24, cutOut = 6.24 },
    { turn =  30, m = OWN .. "merc_kh_bend_left_30.cgf",  yaw = -90,
      px = -0.15, py = 6.35, cutIn = 6.35, cutOut = 6.35 },
    { turn = -30, m = OWN .. "merc_kh_bend_right_30.cgf", yaw = -90,
      px = -0.15, py = 6.35, cutIn = 6.35, cutOut = 6.35 },
    { turn =  45, m = OWN .. "merc_kh_bend_left_45.cgf",  yaw = -90,
      px = -0.15, py = 6.54, cutIn = 6.54, cutOut = 6.54 },
    { turn = -45, m = OWN .. "merc_kh_bend_right_45.cgf", yaw = -90,
      px = -0.15, py = 6.54, cutIn = 6.54, cutOut = 6.54 },
    -- 60 and 75 exist so that every turn build mode lets the player DRAW has a piece.
    -- Snapping is derived as the gcd of these angles, so 15 and 90 alone still allowed a
    -- 60-degree turn to be marked and then left with nothing standing on it. Their radii
    -- are down to 12 m and 9.5 m, which stretches the stone 21% and 26% across the wall's
    -- own thickness - tighter than the gentle turns and visibly so.
    { turn =  60, m = OWN .. "merc_kh_bend_left_60.cgf",  yaw = -90,
      px = -0.15, py = 6.85, cutIn = 6.85, cutOut = 6.85 },
    { turn = -60, m = OWN .. "merc_kh_bend_right_60.cgf", yaw = -90,
      px = -0.15, py = 6.85, cutIn = 6.85, cutOut = 6.85 },
    { turn =  75, m = OWN .. "merc_kh_bend_left_75.cgf",  yaw = -90,
      px = -0.15, py = 7.28, cutIn = 7.28, cutOut = 7.28 },
    { turn = -75, m = OWN .. "merc_kh_bend_right_75.cgf", yaw = -90,
      px = -0.15, py = 7.28, cutIn = 7.28, cutOut = 7.28 },
}

-- Only the big city wall. Its corner arms end in the SAME face the straight piece does -
-- 2.90 m across - so the two meet exactly. kh02 is a 0.70 m wall and the town's yard wall
-- 0.71 m: handing either of them a 2.5 m thick corner would plant a block four times
-- their own width on every turn. They have no corner mesh of their own and take a tower.
-- This cannot live in the loop above: that runs before this table exists.
-- Lids for the two open ends of a run being drawn. The kit's walls are shells with no
-- geometry closing their end faces - in the levels they were cut for there is always
-- another piece against them - so a preview run is see-through where it stops. Only the
-- ghost uses these; a built run ends on a tower or another piece.
mercenaries.KHCap = {
    start  = OWN .. "merc_kh_cap_start.cgf",
    finish = OWN .. "merc_kh_cap_finish.cgf",
}

-- ==== the gateway ====
-- A way through a stone wall is not a gate stood next to it, the way a palisade's is. The
-- kit ships the answer: `wall_kh_gate_a` is a TILE - the same 12.39 m pitch as the plain
-- curtain - with an archway cut through it, so it drops straight into the run in place of
-- one piece and the merlon grid carries on over the top of it.
--
-- Two measurements decide everything, and both are read off the mesh rather than guessed
-- (assets probe, docs/castle.md): the archway is 2.60 m clear, centred 8.75 m along the
-- tile from its origin. `rise` is the one adjustment it needs - the curtain is sunk three
-- metres (`up = -3.00`, a city wall being too tall for a camp) and the archway is cut at
-- the mesh's own ground, so sinking the gate tile with the rest of the wall would bury the
-- opening entirely. Put back, it stands as a gatehouse a little proud of its curtain,
-- which is what a gatehouse does.
-- Is the stone wall buyable? YES from the camp screen, which labels it Experimental, and
-- still NO from the quartermaster: his option stays commented out of quartermaster_dialog.xml
-- in both regions. Two surfaces, and only the one that warns you is open.
--
-- This flag was the second lock while the curtain was being shaken out. It is off the latch
-- now because the camp screen offers it with the warning attached; if it needs locking again,
-- this is still the one switch that stops every purchase path at once. merc_castle_build is
-- unaffected either way - it is a dev command and was always the way in.
mercenaries.CastleWallForSale = true

mercenaries.KHGateway = {
    m      = WAL .. "wall_kh_gate_a.cgf",
    along  = 8.75,        -- archway centre, metres along the tile from its origin
    lat    = 0.00,        -- and across it
    rise   = 0.00,        -- the curtain is no longer sunk, so nothing to undo
    -- the leaves: gate_d is the only pair carved both open and shut that fits a 2.6 m arch
    style  = { n = "kh_arch", width = 2.35,
               open   = DOR .. "gate_d_doors_opened.cgf",
               closed = DOR .. "gate_d_doors_closed.cgf" },
}

-- ==== what the projection is made of ====
-- A 15 m curtain drawn between you and the ground you are drawing on hides the thing you
-- are aiming at. The projection is a low stone fence instead: the same line, ending where
-- the wall will end, and low enough to see over. It follows the ground rather than the
-- run's laid height, because what it is for is showing you WHERE the wall goes.
--
-- The cropped 5 m field wall is the right piece for it - free-standing, modelled on both
-- sides (so no see-through ends to lid) and carrying no buried footing, so it sits on the
-- terrain wherever it is put.
mercenaries.CastleGhostFences = {
    { n = "fence5",      m = FEN .. "stone_fence_5m_noterrain.cgf",
      len = 5.12, ox = -0.11, lat = 0.09, up = 0.00, yaw = 0 },
    { n = "fence5_b",    m = FEN .. "stone_fence_5m_noterrain_b.cgf",
      len = 5.13, ox = -0.11, lat = 0.09, up = 0.00, yaw = 0 },
    { n = "fence16",     m = FEN .. "stone_fence_16m_noterrain.cgf",
      len = 16.76, ox = -0.38, lat = 0.18, up = 0.00, yaw = 0 },
    { n = "fence5_crop", m = FEN .. "stone_fence_5m_noterrain_cropped.cgf",
      len = 5.22, ox = -0.12, lat = 0.08, up = 0.00, yaw = 0 },
    { n = "low_a",       m = RUI .. "wall_low_ruined_kh_a.cgf",
      len = 3.12, ox = -0.00, lat = -0.01, up = 0.00, yaw = 0 },
    { n = "low_b",       m = RUI .. "wall_low_ruined_kh_b.cgf",
      len = 3.10, ox = -0.01, lat = -0.00, up = 0.00, yaw = 0 },
}
mercenaries.CastleGhostIdx = 1
mercenaries.CastleGhostFence = mercenaries.CastleGhostFences[mercenaries.CastleGhostIdx]

for _, t in ipairs(mercenaries.CastleWalls) do
    if t.grp == "kh" and (t.tall or 0) > 9.0 then
        t.corners = mercenaries.CastleCornersKH
        t.towerEvery = 0        -- its own corners close every turn; no tower needed
        t.slope = mercenaries.KHSlope
        t.cap = mercenaries.KHCap
        t.gateway = mercenaries.KHGateway
        t.ghost = mercenaries.CastleGhostFence
        -- NO SINK, and the gatehouse is why. The archway is cut at the mesh's own ground,
        -- so a curtain dropped three metres into the earth cannot have one - the opening
        -- ends up underground. Raising only the gate tile puts its crown six metres proud
        -- of the wall it is cut into, and squashing it to fit wrecks the stonework. The
        -- wall stands at its full 10.2 m instead and the gate tile drops straight in,
        -- level with it, which is also what a city wall is supposed to look like.
        t.up = 0.00
    end
end


-- Where the player has asked for a way through. One point per gateway; the tile nearest
-- each is the one that becomes an arch, so the mark survives the run being refitted.
mercenaries.CastleGateways = {}

function mercenaries:CastleGatewaySpec()
    local wt = self.WallTypes[self.WallTypeIdx] or {}
    return wt.gateway
end

-- The gateway spec for a tile about to be laid at `pos`, or nil for an ordinary tile.
-- Matched on distance because the marks are world points and the tiling that produced
-- them may have shifted since - a refit slides the whole run, and a gateway has to travel
-- with the wall rather than stay behind in the field.
function mercenaries:CastleGatewayFor(pos)
    local spec = self:CastleGatewaySpec()
    if not (spec and pos and #(self.CastleGateways or {}) > 0) then return nil end
    local best, bestD = nil, nil
    for _, g in ipairs(self.CastleGateways) do
        if not g.used then
            local d = (g.x - pos.x) ^ 2 + (g.y - pos.y) ^ 2
            if not bestD or d < bestD then best, bestD = g, d end
        end
    end
    local reach = (tonumber((self.WallTypes[self.WallTypeIdx] or {}).len) or 12.0) * 0.5
    if not best or bestD > reach * reach then return nil end
    best.used = true            -- one tile per mark, however many tiles are in range
    return spec
end

-- Cleared at the start of every rebuild: `used` is a per-rebuild claim, not state.
function mercenaries:CastleGatewayReset()
    for _, g in ipairs(self.CastleGateways or {}) do g.used = nil end
end

-- Hang the leaves in an archway. The tile's origin and yaw are what the builder just
-- placed; the opening is `along` down the tile from there.
function mercenaries:CastleGatewayHang(spec, pos, yaw)
    -- guarded like the rest of the optional wiring: no gate module, no leaves, but the
    -- archway tile still goes up and the wall still builds
    if not (spec and pos and self.GateBuild) then return nil end
    local run = yaw - math.rad(self.WallYawFix or 0)
    local ux, uy = math.cos(run), math.sin(run)
    local a = tonumber(spec.along) or 0
    local lat = tonumber(spec.lat) or 0
    local p = { x = pos.x + ux * a - uy * lat, y = pos.y + uy * a + ux * lat,
                z = pos.z + (tonumber(spec.rise) or 0) }
    -- The gate's LOGICAL yaw is a quarter turn off the way the wall runs, exactly as a
    -- palisade gate's is: GateYawFix turns the mesh back, and the leaves are 2.35 m wide
    -- along their own X. Handing this the run direction instead lies them ACROSS the wall,
    -- where 2.35 m of door disappears inside 3.5 m of masonry - a gate that is built,
    -- recorded, and completely invisible. GateBlockSegments reads the same yaw, so the
    -- seal goes across the opening rather than through the stone.
    --
    -- noSnap: the archway's floor is the wall's, not the terrain's - re-reading the ground
    -- here would drop the leaves through the gatehouse's own foundation
    return self:GateBuild(p, run + math.pi / 2, false, true, spec.style, "gateway")
end

-- Mark a way through where the player is looking. The tile nearest that point becomes an
-- archway at the next rebuild.
function mercenaries:CastleGatewayPlace(pos)
    if not self:CastleGatewaySpec() then
        cLog("this wall type has no gateway piece")
        Game.SendInfoText('merc_info_castle_gateway_none', false, 0, 4)
        return false
    end
    pos = pos or (self.TowerLookedAtPos and self:TowerLookedAtPos())
    if not pos then Game.SendInfoText('merc_info_tower_aim', false, 0, 3); return false end
    if not (self.WallHasAny and self:WallHasAny()) then
        cLog("no wall to cut a gateway into")
        Game.SendInfoText('merc_info_castle_gateway_nowall', false, 0, 4)
        return false
    end
    table.insert(self.CastleGateways, { x = pos.x, y = pos.y, z = pos.z })
    self:WallRebuild()
    pcall(function() if self.DefSave then self:DefSave() end end)
    cLog(string.format("gateway %d marked at %.1f, %.1f",
                       #self.CastleGateways, pos.x, pos.y))
    return true
end

-- Aim-and-click, the same placement the tower, the cart and the palisade gate use. The
-- ghost is the archway tile itself, so what you are lining up is the thing that gets
-- built; it stands where the tile will, which is why it is offered at the tile's own
-- height rather than on the ground.
function mercenaries:CastleGatewayPlaceSpec()
    local spec = self:CastleGatewaySpec() or {}
    return {
        parts = { { model = spec.m, x = 0, y = 0, z = 0, rx = 0, ry = 0, rz = 0 } },
        validMaterial = nil,
        sink = 0,
        isValid = function(s, pos) return s:CastleGatewaySpotIsValid(pos) end,
        confirm = function(s, pos) s:CastleGatewayPlace(pos) end,
        info = { placing = 'merc_info_castle_gateway_placing',
                 aim = 'merc_info_tower_aim',
                 blocked = 'merc_info_castle_gateway_blocked',
                 cancelled = 'merc_info_gate_cancelled' },
    }
end

-- A gateway has to be ON the wall, and not on top of another one.
function mercenaries:CastleGatewaySpotIsValid(pos)
    if not pos then return false end
    for _, g in ipairs(self.CastleGateways or {}) do
        local dx, dy = pos.x - g.x, pos.y - g.y
        if (dx * dx + dy * dy) < 100.0 then return false end
    end
    local near = nil
    pcall(function() near = self:WallNearestDist(pos) end)
    return (near ~= nil) and near < 8.0
end

function mercenaries:StartCastleGatewayPlacement()
    self:StartPlacement(self:CastleGatewayPlaceSpec())
end

-- ==== a way in, without being asked ====
-- A wall you cannot walk through is no use, so a stone run cuts itself a gatehouse the
-- moment it is finished. Nobody buys it separately; it comes with the wall.
--
-- "Somewhere convenient" is two rules. It must be on a STRAIGHT stretch with a whole tile
-- of wall either side of it - a gatehouse jammed against a corner has nowhere to put its
-- approach, and the corner's own arm would swallow half of it. Among those, it goes on the
-- side of the camp the player is actually standing on, which is the side they have been
-- walking in and out of while they built the thing.
function mercenaries:CastleGatewayAuto()
    if not self:CastleGatewaySpec() then return false end
    if #(self.CastleGateways or {}) > 0 then return false end     -- already has a way in

    local best, bestD = nil, nil
    local pp = nil
    pcall(function() pp = player and player:GetWorldPos() end)

    local saved = self.WallLevelZ
    for _, r in ipairs(self:WallAllRuns()) do
        local m = r.pts
        local edges = {}
        for i = 1, #m - 1 do edges[#edges + 1] = { m[i], m[i + 1], i, i + 1 } end
        if r.closed and #m > 2 then edges[#edges + 1] = { m[#m], m[1], #m, 1 } end
        for _, e in ipairs(edges) do
            local segs = {}
            pcall(function()
                self.WallLevelZ = nil
                self:WallClimbReset()
                segs = self:WallEdgeSegments(e[1], e[2], "cover",
                                             self:WallVertexCut(r, e[3], "out"),
                                             self:WallVertexCut(r, e[4], "in")) or {}
            end)
            -- a whole tile of wall either side, so never the first or last of an edge
            for i = 2, #segs - 1 do
                local q = segs[i].pos
                local d = pp and ((q.x - pp.x) ^ 2 + (q.y - pp.y) ^ 2)
                             or ((#segs - i) * 1.0)
                if not bestD or d < bestD then best, bestD = { x = q.x, y = q.y, z = q.z }, d end
            end
        end
    end
    self.WallLevelZ = saved

    if not best then
        cLog("no stretch long enough for a gatehouse - three tiles are needed")
        return false
    end
    table.insert(self.CastleGateways, best)
    self:WallRebuild()
    pcall(function() if self.DefSave then self:DefSave() end end)
    cLog(string.format("a gatehouse was cut in at %.1f, %.1f", best.x, best.y))
    Game.SendInfoText('merc_info_castle_gateway_cut', false, 0, 4)
    return true
end

-- Swap the piece the projection is drawn with. Every wall type that has one is pointed at
-- the new choice, because the projection is a property of the BUILDER, not of the wall.
function mercenaries:CastleSetGhost(v)
    local i = tonumber(castleArg(v))
    if not (i and self.CastleGhostFences[i]) then
        cLog("projection pieces:")
        for k, g in ipairs(self.CastleGhostFences) do
            cLog(string.format("  %d = %-12s (%.2f m tiles)%s", k, g.n, g.len,
                (k == self.CastleGhostIdx) and "  <- current" or ""))
        end
        return
    end
    self.CastleGhostIdx = i
    self.CastleGhostFence = self.CastleGhostFences[i]
    for _, t in ipairs(self.WallTypes or {}) do
        if t.ghost then t.ghost = self.CastleGhostFence end
    end
    cLog("projection = " .. self.CastleGhostFence.n)
end

-- Walk the whole gateway chain and say where it breaks. Run it standing in the camp.
-- Every step of "mark -> archway tile -> gate record -> entity in the world" is reported
-- separately, because they fail for completely different reasons and the symptom - an
-- empty arch - looks the same for all of them.
function mercenaries:CastleGatewayProbe()
    local function say(s) System.LogAlways("[GwProbe] " .. s) end
    local wt = self.WallTypes[self.WallTypeIdx] or {}
    say(string.format("wall type %s, gateway piece %s", tostring(wt.n),
        wt.gateway and "yes" or "NO - this wall has no archway tile"))
    say(string.format("marks: %d", #(self.CastleGateways or {})))
    for i, g in ipairs(self.CastleGateways or {}) do
        say(string.format("  mark %d at %.1f, %.1f (used this rebuild: %s)",
            i, g.x, g.y, g.used and "yes" or "no"))
    end

    local hung = {}
    for i, g in ipairs(self.Gates or {}) do
        if g.tag == "gateway" then table.insert(hung, { i = i, g = g }) end
    end
    say(string.format("gate records tagged gateway: %d (of %d gates in all)",
        #hung, #(self.Gates or {})))
    if #hung == 0 and #(self.CastleGateways or {}) > 0 then
        say("  -> the tile was swapped but no leaves were hung. CastleGatewayHang bailed:")
        say("     GateBuild present: " .. tostring(self.GateBuild ~= nil))
    end

    for _, h in ipairs(hung) do
        local g = h.g
        local st = g.style or {}
        say(string.format("  gate %d at %.2f, %.2f, %.2f yaw %.1f deg, style %s",
            h.i, g.x, g.y, g.z, math.deg(g.yaw or 0), tostring(st.n)))
        say(string.format("     model %s", tostring(self:GateModel(g.open, g))))
        local ent = g.ent and System.GetEntity(g.ent)
        if not ent then
            say("     NO ENTITY - the leaves were never spawned, or something removed them")
        else
            local wp; pcall(function() wp = ent:GetWorldPos() end)
            say(string.format("     entity %s as class %s at %.2f, %.2f, %.2f",
                tostring(ent:GetName()), tostring(g.entClass),
                wp and wp.x or 0, wp and wp.y or 0, wp and wp.z or 0))
            local vis; pcall(function() vis = ent:IsHidden() end)
            say("     hidden: " .. tostring(vis))
            -- the leaves must stand at the archway's own floor; a metre out either way
            -- and they are through the foundation or hovering in the opening
            if wp then
                local dz = wp.z - (g.z or 0)
                say(string.format("     %.2f m off the height it was hung at", dz))
            end
        end
        say(string.format("     colliders: %d", #(g.colliders or {})))
    end
    if #hung == 0 and #(self.CastleGateways or {}) == 0 then
        say("nothing to report: this camp has no gateway. Build a stone wall, or "
            .. "merc_castle_gateway to cut one.")
    end
end

function mercenaries:CastleGatewayClearAll()
    self.CastleGateways = {}
    self:WallRebuild()
    pcall(function() if self.DefSave then self:DefSave() end end)
    cLog("gateways cleared")
end

-- How many corners apart the towers stand. 1 puts one on every corner - which is what
-- a wall type with no corner pieces does whatever this says, having nothing else to
-- close a turn with - and 0 leaves the corner pieces to carry all of them.
mercenaries.CastleTowerEvery = 2
mercenaries.CastleTowerEveryDefault = 2   -- restored for a type that states none

-- `turn` is signed, positive to the left. A wall type may carry its own corner list;
-- `corners = true` means the shared one, which only has left-hand pieces.
function mercenaries:CastleCornerList(wt)
    if not (wt and wt.corners) then return nil end
    return (type(wt.corners) == "table") and wt.corners or self.CastleCorners
end

-- The coarsest angle every corner piece this wall type owns is a multiple of, which is
-- the angle build mode should snap to. Ours ship 45/90/135, so 45. The walltool kit
-- ships only a 90 pair, so 45 lets the player draw a turn there is no mesh for - which
-- is exactly what a wedge of daylight at a corner looks like. Derived rather than
-- declared, so it cannot drift out of step with the list.
function mercenaries:CastleSnapAngleFor(wt)
    local list = self:CastleCornerList(wt)
    if not list then return nil end
    local function gcd(a, b) while b > 0 do a, b = b, a % b end return a end
    local g = 0
    for _, c in ipairs(list) do
        g = gcd(g, math.abs(math.floor(tonumber(c.turn) or 0)))
    end
    return (g >= 1) and g or nil
end

function mercenaries:CastleCornerFor(turn, wt)
    if not self.CastleCornersOn then return nil end
    local list = self:CastleCornerList(wt)
    if not list then return nil end
    for _, c in ipairs(list) do
        if math.abs(turn - c.turn) < TURN_MIN then return c end
    end
    return nil
end

-- Stand a corner mesh so its own turning point sits on the marked corner. `px`/`py` are
-- where that point is inside the mesh; without this the piece is placed by its origin,
-- which on the walltool corners is 5 m back down the incoming wall.
function mercenaries:CastleCornerOffset(corner, ain)
    local px, py = tonumber(corner.px) or 0, tonumber(corner.py) or 0
    if px == 0 and py == 0 then return 0, 0 end
    local yaw = ain + math.rad(tonumber(corner.yaw) or 0)
    local c, s = math.cos(yaw), math.sin(yaw)
    return -(px * c - py * s), -(px * s + py * c)
end

-- Counted along the run, so the same castle comes back the same way after a reload.
function mercenaries:CastleTowerDue(r, i)
    local wt = self.WallTypes[self.WallTypeIdx] or {}
    if not (self.CastleCornersOn and wt.corners) then return true end
    local every = math.floor(tonumber(self.CastleTowerEvery) or 1)
    if every < 1 then return false end
    if every == 1 then return true end
    local ord = 0
    for j = 1, #r.pts do
        if turnAt(r, j) then
            ord = ord + 1
            if j == i then return (ord % every) == 0 end
        end
    end
    return false
end

-- What stands on vertex i of run r: nothing, a corner piece, or a tower.
--
-- The EDGE builder and the PIECE builder both read this. A piece on a corner the walls
-- have not stepped back from puts two sets of merlons in the same two metres; walls
-- stepping back for a piece that never spawns leaves a 4m hole. One answer, read
-- twice, is what keeps the two in step.
function mercenaries:CastleVertexPlan(r, i)
    local m, n = r.pts, #r.pts
    if n < 2 then return nil end

    -- Towers are part of a castle, not of a palisade: a stone tower on the corner of a
    -- timber fence is what `castle` keeps out here. CastleVertexActive already answered
    -- "nothing stands on a palisade corner"; this is the same answer given twice.
    local wt = self.WallTypes[self.WallTypeIdx] or {}
    local tspec = self:CastleTowerSpec()
    if not (self.CastleTowersOn and wt.castle and tspec and tspec.m) then tspec = nil end
    -- The tower's `cut`, its step onto the walk and its height are all measured against
    -- OUR wall. On a base-game segment - a different thickness, a different length, a
    -- walk it may not even have - none of them mean anything, so it just stands on the
    -- corner as it always did.
    local own = (wt.towerkit == true or wt.corners == true)

    -- `bis` is the direction the piece steps off the corner in, `lat` how far: the wall
    -- walk runs up the INSIDE of the curtain and the tower's doorways are on its centre
    -- lines, so the tower moves inboard until the two line up.
    --
    -- `blocked` are the directions walls arrive from. All four turns of a square put a
    -- face on the walls. The rebuilt tower's offset ground door stays in the courtyard
    -- beside its connecting curtain; its blind stair bay faces away from those walls.
    -- Older tower types retain their existing door-facing rule.
    local function tower(yaw, bis, spread, blocked)
        if not tspec then return nil end
        if tspec.door and bis then
            local best, score = yaw, -math.huge
            for k = 0, 3 do
                local turned = yaw + k * math.pi / 2
                local door = turned - math.pi / 2       -- the door is on the tower's -Y
                local s = math.cos(door - bis)
                -- The new ground door is offset into the courtyard, clear of a
                -- curtain joining the centre of this face. Its rear stair bay
                -- has no walk port and must face away from connecting walls.
                if tspec.doorOffset then
                    s = s + 0.5 * math.cos(turned - bis)
                end
                for _, b in ipairs(blocked or {}) do
                    if tspec.rearBlind then
                        if math.cos(turned + math.pi / 2 - b) > 0.7 then s = s - 20 end
                    elseif math.cos(door - b) > 0.7 then s = s - 10 end
                end
                if s > score then best, score = turned, s end
            end
            yaw = best
        end
        local a = yaw + math.rad(self.CastleTowerYaw or 0)
        local model = (own and wt.walkheight == 6.00 and tspec.tall) or tspec.m
        local pl = { kind = "tower", m = model, mtl = tspec.mtl, yaw = a,
                     cut = own and (tonumber(tspec.cut) or 0) or 0,
                     up  = (tonumber(self.CastleTowerUp) or tspec.up or 0)
                           + ((own and tspec.wallup) and (self.WallUp or 0) or 0) }
        if own and tspec.rearBlind then
            pl.decor = (wt.walkheight == 6.00) and "castle_tower_hand" or "castle_tower"
            pl.decorCount = 4
        end
        local lat = own and (tonumber(tspec.lat) or 0) or 0
        if own and tspec.rearBlind then lat = wt.walkcenter or lat end
        if lat ~= 0 and bis then
            lat = lat / math.max(math.abs(spread or 1), 0.35)
            pl.dx, pl.dy = math.cos(bis) * lat, math.sin(bis) * lat
        end
        return pl
    end

    -- A run's own ends: where the curtain stops, which is exactly where a tower belongs.
    if not r.closed and (i == 1 or i == n) then
        if r.flushEnd and i == n then return nil end        -- that end belongs to the gate
        if not self.CastleTowerEnds then return nil end
        -- A kit that can finish its own ends does. `own` is false when the selected tower
        -- is not one this wall owns - our Blender tower on the end of the Kuttenberg
        -- curtain is a different wall's block, at a different height and in different
        -- stone, and it reads as a corner that failed to appear rather than as a finish.
        -- The end takes the wall's own lid instead (WallSpawnCap).
        if wt.cap and not own then return nil end
        local a, b = (i == 1) and m[1] or m[n - 1], (i == 1) and m[2] or m[n]
        local yaw = math.atan2(b.y - a.y, b.x - a.x)
        -- the curtain leaves the first mark going forward and reaches the last one from
        -- behind, so those are the faces it takes up
        return tower(yaw, yaw + math.pi / 2, 1, { (i == 1) and yaw or (yaw + math.pi) })
    end

    local turn, ain = turnAt(r, i)
    if not turn then return nil end                          -- straight on: nothing to fill

    local wt = self.WallTypes[self.WallTypeIdx] or {}
    local corner = self:CastleCornerFor(turn, wt)
    -- No piece for this angle: a tower is the fallback, and it has to be allowed even
    -- when `towerEvery` is 0. That setting means "the corners can close every turn" -
    -- which is only true of the turns they HAVE a piece for. Without this a turn the
    -- player can draw but the kit cannot make gets nothing standing on it at all.
    if not corner and tspec and tspec.m and self.CastleTowersOn
       and self:CastleCornerList(wt) then
        return tower(ain + math.rad((turn % 90) / 2),
                     ain + math.rad(turn / 2) + math.pi / 2,
                     math.cos(math.rad(turn / 2)),
                     { ain + math.pi, ain + math.rad(turn) })
    end
    if corner and (not (tspec and self:CastleTowerDue(r, i))
                   or (tspec.rearBlind and math.abs(math.abs(turn) - 90) > TURN_MIN)) then
        local arm = corner.cut or tonumber(self.CastleCornerArm) or 2.00
        local dx, dy = self:CastleCornerOffset(corner, ain)
        return { kind = "corner", m = corner.m, mtl = corner.mtl,
                 yaw = ain + math.rad(tonumber(corner.yaw) or 0),
                 cut = arm, cutIn = corner.cutIn or arm, cutOut = corner.cutOut or arm,
                 dx = dx, dy = dy, up = self.WallUp or 0 }
    end

    -- A SQUARE tower puts a face on each of the two walls, so it turns to the 90-degree
    -- lattice closest to both - not to the bisector, which is where a round one would
    -- go and which stands a square one on its diagonal at every right-angled corner.
    return tower(ain + math.rad((turn % 90) / 2),
                 ain + math.rad(turn / 2) + math.pi / 2,
                 math.cos(math.rad(turn / 2)),
                 { ain + math.pi, ain + math.rad(turn) })
end

-- Spawned into WallSegEnts, so they are cleared and rebuilt with the wall they belong
-- to and need no bookkeeping of their own.
function mercenaries:CastleSpawnVertex(pl, at, atZ)
    if not (pl and pl.m and at) then return nil end
    local p = { x = at.x + (pl.dx or 0), y = at.y + (pl.dy or 0), z = at.z }
    if self.WallSnap and self.CampSnapToGround then p = self:CampSnapToGround(p) end
    -- A corner stands on the curtain, not on the ground under it. `atZ` is the height the
    -- run has actually climbed to by this marker; falling back to the run's base level
    -- leaves the corner where the wall STARTED, which on a slope is metres below it.
    if atZ then p.z = atZ
    elseif self.WallLevelZ then p.z = self.WallLevelZ end
    p.z = p.z + (pl.up or 0)
    local a = pl.yaw or 0

    local params = {
        class = "mercenaries_Prop",
        name = "MercCastle" .. ((pl.kind == "corner") and "Corner_" or "Tower_")
               .. tostring(math.random(100000, 999999)),
        position = p,
        orientation = { x = math.cos(a), y = math.sin(a), z = 0 },
        properties = { object_Model = pl.m, bMissionCritical = false,
                       bSaved_by_game = false, bSerialize = false },
    }
    local ent = System.SpawnEntity(params)
    if not ent then
        params.class = "BasicEntity"
        params.properties.Physics = { bPhysicalize = true, bRigidBody = false,
                                      Mass = 0, Density = 0, bPushableByPlayers = false }
        ent = System.SpawnEntity(params)
    end
    if ent then
        pcall(function() ent:SetAngles({ x = 0, y = 0, z = a }) end)
        pcall(function() ent:SetViewDistUnlimited() end)
        pcall(function() ent:SetViewDistRatio(255) end)
        pcall(function() ent:SetLodRatio(255) end)
        pcall(function() ent:RenderShadow(true) end)
        if pl.mtl then pcall(function() ent:SetMaterial(pl.mtl) end) end
        table.insert(self.WallSegEnts, ent.id)
        if pl.decor then self:WallSpawnDecor(pl, p, a) end
    end
    return ent
end

-- Every corner of every run, and both ends of an open one.
function mercenaries:CastleBuildVertices()
    local count = 0
    for _, r in ipairs(self:WallAllRuns()) do
        for i = 1, #r.pts do
            local pl = self:CastleVertexPlan(r, i)
            local z = r.vertexZ and r.vertexZ[i]
            if pl and self:CastleSpawnVertex(pl, r.pts[i], z) then count = count + 1 end
        end
    end
    return count
end

-- How much of the edge on either side of vertex i the piece standing on it takes up.
-- Read by the edge builder, which starts the tiling that far along.
function mercenaries:CastleVertexCut(r, i, side)
    local pl = self:CastleVertexPlan(r, i)
    if not pl then return 0 end
    if side == "in"  then return pl.cutIn  or pl.cut or 0 end
    if side == "out" then return pl.cutOut or pl.cut or 0 end
    return pl.cut or 0
end

-- Whether anything on a corner eats into the run at all. While nothing does, marking a
-- corner can just extend the wall instead of rebuilding the whole run.
function mercenaries:CastleVertexActive()
    local wt = self.WallTypes[self.WallTypeIdx] or {}
    if not (wt.corners or wt.towerkit) then return false end
    if wt.corners and self.CastleCornersOn then return true end
    local t = self:CastleTowerSpec()
    return (self.CastleTowersOn and wt.castle and t and t.m and (tonumber(t.cut) or 0) > 0) and true or false
end

-- A ring drawn CLOCKWISE has its battlements facing the courtyard: the outer face is on
-- the right of the direction of travel, and every corner of it turns right, which is
-- the one turn the corner pieces cannot make. Walking the same ring the other way round
-- is the whole fix. Finished runs only - reversing the one being drawn would move the
-- corner the player is building from.
function mercenaries:CastleFixWinding()
    local flipped = 0
    for _, r in ipairs(self.WallRuns or {}) do
        if r.closed and not r.flushEnd and r.pts and #r.pts >= 3 then
            local m, area = r.pts, 0
            for i = 1, #m do
                local j = i % #m + 1
                area = area + (m[i].x * m[j].y - m[j].x * m[i].y)
            end
            if area < 0 then
                for i = 1, math.floor(#m / 2) do
                    m[i], m[#m - i + 1] = m[#m - i + 1], m[i]
                end
                flipped = flipped + 1
            end
        end
    end
    if flipped > 0 then
        cLog(flipped .. " ring(s) drawn clockwise: walked the other way round, so the"
             .. " battlements face out and the corners turn the way the pieces are cut")
    end
    return flipped
end

-- ==== commands ====

-- Put the castle settings in force. Switching the wall type reloads that type's own
-- len/up/lat, exactly as merc_wall_type does, so a castle piece never inherits the
-- palisade's -3.00 sink.
function mercenaries:CastleApply(quiet)
    local idx = self.CastleWallBase + self.CastleWallIdx
    if not self.WallTypes[idx] then cLog("no castle wall " .. self.CastleWallIdx); return end
    self:WallSetType(idx)
    if not quiet then self:CastleStatus() end
end

function mercenaries:CastleBuild()
    self:CastleApply(true)
    local wall  = (self:CastleWallType() or {}).n or "?"
    local tower = self.CastleTowersOn and (self:CastleTowerSpec() or {}).n or "none"
    local gate  = ((self.GateStyles or {})[self.GateStyleIdx] or {}).n or "?"
    cLog("stone: " .. wall .. ", towers: " .. tower .. ", gate: " .. gate)
    self:StartWallBuild()
end

-- Back to the palisade: the wall type the camp shipped with, towers off.
function mercenaries:CastleOff()
    self.CastleTowersOn = false
    self:WallSetType(3)
    cLog("back to the palisade (type 3), towers off")
end

function mercenaries:CastleSetWall(v)
    local i = tonumber(castleArg(v))
    if not (i and self.CastleWalls[i]) then
        cLog("stone segments:")
        for k, t in ipairs(self.CastleWalls) do
            cLog(string.format("  %-2d %-8s %-13s len %5.2f  %s", k, t.grp or "?", t.n, t.len,
                (k == self.CastleWallIdx) and "<- current" or ""))
        end
        return
    end
    self.CastleWallIdx = i
    self:CastleApply(true)
    cLog("segment " .. i .. " = " .. self.CastleWalls[i].n
         .. " (merc_wall_len / merc_wall_up to fit it)")
end

function mercenaries:CastleSetTower(v)
    local i = tonumber(castleArg(v))
    if not (i and self.CastleTowers[i]) then
        cLog("corner towers:")
        for k, t in ipairs(self.CastleTowers) do
            cLog(string.format("  %-2d %-13s %s", k, t.n,
                (k == self.CastleTowerIdx) and "<- current" or ""))
        end
        return
    end
    self.CastleTowerIdx = i
    self.CastleTowerUp = nil          -- back to the new tower's own offset
    self.CastleTowersOn = (self.CastleTowers[i].m ~= nil)
    cLog("tower " .. i .. " = " .. self.CastleTowers[i].n)
    self:WallRebuild()
end

-- The castle gates only. merc_gate_style still reaches every style including the
-- palisade's, which is not what someone building in stone wants to scroll past.
function mercenaries:CastleSetGate(v)
    local i = tonumber(castleArg(v))
    if not (i and self.CastleGates[i]) then
        cLog("gates:")
        for k, g in ipairs(self.CastleGates) do
            cLog(string.format("  %-2d %-12s width %.1f%s%s", k, g.n, g.width or 4.0,
                g.frame and "  (arch, no leaves)" or "  (swings)",
                (self.GateStyleIdx == self.CastleGateBase + k) and "  <- current" or ""))
        end
        return
    end
    self.GateStyleIdx = self.CastleGateBase + i
    cLog("gate " .. i .. " = " .. self.CastleGates[i].n
         .. " (merc_gate_width / merc_gate_sink / merc_gate_yawfix to fit it)")
end

function mercenaries:CastleSetTowers(v)
    self.CastleTowersOn = (tonumber(castleArg(v)) == 1)
    cLog("corner towers " .. (self.CastleTowersOn and "on" or "off"))
    self:WallRebuild()
end

function mercenaries:CastleSetEnds(v)
    self.CastleTowerEnds = (tonumber(castleArg(v)) == 1)
    cLog("towers on open ends " .. (self.CastleTowerEnds and "on" or "off"))
    self:WallRebuild()
end

function mercenaries:CastleSetCorners(v)
    self.CastleCornersOn = (tonumber(castleArg(v)) == 1)
    cLog("corner pieces " .. (self.CastleCornersOn and "on" or "off")
         .. (self.CastleCornersOn and "" or " - every turn now takes a tower instead"))
    self:WallRebuild()
end

function mercenaries:CastleSetTowerEvery(v)
    local n = math.floor(tonumber(castleArg(v)) or 0)
    self.CastleTowerEvery = math.max(0, n)
    if self.CastleTowerEvery == 0 then
        cLog("no towers on the corners - the corner pieces carry every turn")
    elseif self.CastleTowerEvery == 1 then
        cLog("a tower on every corner")
    else
        cLog(string.format("a tower every %d corners, corner pieces on the rest",
                           self.CastleTowerEvery))
    end
    self:WallRebuild()
end

-- Turn the doubled back face on or off for the CURRENT type. Every mesh in the list is
-- a stand-alone prop rather than a level facade, so they all ship with it off; this is
-- here for the one that turns out to be hollow after all.
function mercenaries:CastleSetBack(v)
    local t = self:CastleWallType()
    if not t then cLog("no castle segment selected"); return end
    t.back = (tonumber(castleArg(v)) == 1)
    cLog(t.n .. " back face " .. (t.back and "on" or "off"))
    self:WallRebuild()
end

function mercenaries:CastleSetThick(v)
    self.CastleThick = tonumber(castleArg(v)) or 0
    cLog(string.format("wall thickness %.2fm%s", self.CastleThick,
        (self.CastleThick == 0) and " (back faces off - one-sided walls will be see-through)" or ""))
    self:WallRebuild()
end

function mercenaries:CastleSetTowerUp(v)
    self.CastleTowerUp = tonumber(castleArg(v)) or 0
    cLog(string.format("tower height offset %.2fm", self.CastleTowerUp))
    self:WallRebuild()
end

function mercenaries:CastleSetTowerYaw(v)
    self.CastleTowerYaw = tonumber(castleArg(v)) or 0
    cLog(string.format("tower yaw +%.0f", self.CastleTowerYaw))
    self:WallRebuild()
end

function mercenaries:CastleStatus()
    local t = self:CastleWallType()
    local gs = (self.GateStyles or {})[self.GateStyleIdx] or {}
    cLog(string.format("segment %d %s  len %.2f  up %.2f  yaw+%d",
        self.CastleWallIdx, t and t.n or "?",
        tonumber(self.WallSegLen) or (t and t.len) or 0,
        self.WallUp or 0, self.WallYawFix or 0))
    cLog(string.format("towers %s %s  up %s  yaw+%d  ends %s  every %d corner(s)",
        self.CastleTowersOn and "on" or "off", (self:CastleTowerSpec() or {}).n or "?",
        self.CastleTowerUp and string.format("%.2f", self.CastleTowerUp) or "(own)",
        self.CastleTowerYaw or 0, self.CastleTowerEnds and "yes" or "no",
        math.floor(tonumber(self.CastleTowerEvery) or 1)))
    cLog(string.format("corner pieces %s%s", self.CastleCornersOn and "on" or "off",
        (t and t.corners) and " (45/90/135, 2.00m each side of the turn)"
                          or " - this segment has none cut for it, so its turns take towers"))
    cLog(string.format("thickness %.2f   gate %s (width %.1f)",
        self.CastleThick or 0, gs.n or "?", gs.width or 0))
end

-- Print the piece you have just fitted as a table row. The guessed lengths in
-- CastleWalls are meant to be replaced by whatever actually closed the seam in play.
function mercenaries:CastleTune()
    local t = self:CastleWallType()
    if not t then cLog("no castle segment selected"); return end
    local len = tonumber(self.WallSegLen) or t.len or 2.0
    t.len = len
    t.up  = self.WallUp or 0
    t.lat = self.WallLat or 0
    cLog(string.format(
        '{ n = "%s", grp = "%s", m = "%s",%s len = %.2f, up = %.2f, lat = %.2f, back = %s, castle = true },',
        t.n, t.grp or "?", t.m, t.mtl and (' mtl = "' .. t.mtl .. '",') or "",
        len, t.up, t.lat, tostring(t.back == true)))
    local spec = self:CastleTowerSpec()
    if spec and spec.m then
        cLog(string.format('{ n = "%s", m = "%s", up = %.2f },', spec.n, spec.m,
            tonumber(self.CastleTowerUp) or spec.up or 0))
    end
    cLog("yaw fix " .. (self.WallYawFix or 0) .. ", thickness " .. string.format("%.2f", self.CastleThick or 0))
end

function mercenaries:CastleHelp()
    local lines = {
        "===== Castle builder =====",
        "merc_castle_square [n] [m]  lay an EXACT rectangle - drawing one by hand cannot close perfectly",
        "merc_castle_rects [picks|group|all]  a closed rectangle of each candidate, laid out to walk round",
        "merc_castle_tower_row [wall]  every tower candidate with the curtain running into it",
        "merc_castle_matrix <group>  lay a group out as tiled sample runs and walk it (castle, fence, seg, low, rubble)",
        "merc_castle_build      start drawing: left-click a corner, right-click finishes",
        "                       reach an existing wall and the click hangs the GATE instead",
        "merc_castle_wall <n>   stone segment (no arg lists them)",
        "merc_castle_tower <n>  corner tower, 1 = none (no arg lists them)",
        "merc_castle_gate <n>   which gate the run closes with (no arg lists them)",
        "merc_castle_towers <01>  corner towers on or off",
        "merc_castle_tower_every <n>  a tower every n corners (1 = all of them, 0 = none)",
        "merc_castle_corners <01>  corner PIECES on the turns a tower is not standing on",
        "merc_castle_ends <01>  towers on the open ends of a run as well as its corners",
        "merc_castle_thick <m>  wall thickness of the back-face copy",
        "merc_castle_back <01>  double the current segment, for one that is hollow behind",
        "merc_castle_tower_up <m>   sink or raise the towers",
        "merc_castle_tower_yaw <d>  spin the towers",
        "merc_castle_status     what is currently set",
        "merc_castle_tune       print the fitted segment as a table row",
        "merc_castle_off        back to the palisade",
        "Fitting a segment uses the palisade's own tuners: merc_wall_len (spacing),",
        "merc_wall_up (height), merc_wall_yaw (try 90 if pieces run across the edge).",
        "merc_wall_undo / merc_wall_undo_run / merc_wall_clear work as they always did.",
    }
    for _, l in ipairs(lines) do System.LogAlways(l) end
end

-- ==== the lineup ====
-- A gallery of single meshes says nothing about whether a piece works as a WALL. This
-- lays every candidate out as a short tiled RUN at its own length, with its back-face
-- copy and its corner tower, so a piece that does not repeat, does not meet its
-- neighbour or is the wrong height is obvious from the row it is in.
mercenaries.CastleMxEnts   = {}
mercenaries.CastleMxRunLen = 14.0    -- world length of each sample run, so rows compare
mercenaries.CastleMxPitch  =  9.0    -- gap between rows
mercenaries.CastleMxArgs   = ""

local function castleMxSpawn(self, model, pos, yaw, mtl)
    local params = {
        class = "mercenaries_Prop",
        name = "MercCastleMx_" .. tostring(math.random(100000, 999999)),
        position = pos,
        orientation = { x = math.cos(yaw), y = math.sin(yaw), z = 0 },
        properties = { object_Model = model, bMissionCritical = false,
                       bSaved_by_game = false, bSerialize = false },
    }
    local ent = System.SpawnEntity(params)
    if not ent then
        params.class = "BasicEntity"
        params.properties.Physics = { bPhysicalize = true, bRigidBody = false,
                                      Mass = 0, Density = 0, bPushableByPlayers = false }
        ent = System.SpawnEntity(params)
    end
    if ent then
        pcall(function() ent:SetAngles({ x = 0, y = 0, z = yaw }) end)
        pcall(function() ent:SetViewDistUnlimited() end)
        pcall(function() ent:SetViewDistRatio(255) end)
        pcall(function() ent:SetLodRatio(255) end)
        if mtl then pcall(function() ent:SetMaterial(mtl) end) end
        table.insert(self.CastleMxEnts, { id = ent.id, x = pos.x, y = pos.y })
    end
    return ent
end

function mercenaries:CastleMatrixClear()
    for _, e in ipairs(self.CastleMxEnts or {}) do
        pcall(function() System.RemoveEntity(e.id) end)
    end
    self.CastleMxEnts = {}
end

-- merc_castle_matrix [group|all] [runlength] [rowpitch] [towers 0|1]
-- The group is optional: a first word that is not a number is read as one, so
-- `merc_castle_matrix curtain` and `merc_castle_matrix 20` both do what they look like.
function mercenaries:CastleMatrix(line)
    local a = {}
    for w in castleArg(line):gmatch("%S+") do a[#a + 1] = w end
    local grp
    if a[1] and not tonumber(a[1]) then grp = string.lower(table.remove(a, 1)) end
    if grp == "all" then grp = nil end
    local runLen = tonumber(a[1]) or self.CastleMxRunLen
    local pitch  = tonumber(a[2]) or self.CastleMxPitch
    local towers = (a[3] == nil or tonumber(a[3]) ~= 0)
    self.CastleMxArgs = castleArg(line)

    local want = {}
    for i, t in ipairs(self.CastleWalls) do
        if not grp or t.grp == grp then table.insert(want, { i = i, t = t }) end
    end
    if #want == 0 then
        System.LogAlways("[Castle] no group called '" .. tostring(grp) .. "' - try: " .. self:CastleGroupWords())
        return
    end

    self:CastleMatrixClear()
    if not player then return end

    local o = player:GetWorldPos()
    local ang; pcall(function() ang = player:GetWorldAngles() end)
    local pyaw = (ang and ang.z) or 0
    local fx, fy = math.cos(pyaw), math.sin(pyaw)
    local rx, ry = -fy, fx
    -- the run goes left to right across your facing, and each piece is turned the way
    -- the builder would turn it for an edge running that way
    local yaw = math.atan2(ry, rx) + math.rad(self.WallYawFix or 0)
    local thick = tonumber(self.CastleThick) or 0
    local tspec = self:CastleTowerSpec()

    local n = 0
    for row, w in ipairs(want) do
        local i, t = w.i, w.t
        local len = t.len or 2.0
        if len < 0.1 then len = 0.1 end
        local cnt = math.max(2, math.floor(runLen / len))
        local span = cnt * len
        local fwd  = 14.0 + (row - 1) * pitch

        for k = 0, cnt - 1 do
            local lat = -span * 0.5 + (k + 0.5) * len
            local p = { x = o.x + fx * fwd + rx * lat,
                        y = o.y + fy * fwd + ry * lat, z = o.z }
            if self.CampSnapToGround then p = self:CampSnapToGround(p) end
            p.z = p.z + (t.up or 0)
            if castleMxSpawn(self, t.m, p, yaw, t.mtl) then n = n + 1 end
            -- exactly what the builder would put behind it, so a facade that needs the
            -- doubling and one that does not are told apart from the same row
            if t.back and thick ~= 0 then
                castleMxSpawn(self, t.m, { x = p.x - math.sin(yaw) * thick,
                                           y = p.y + math.cos(yaw) * thick,
                                           z = p.z }, yaw + math.pi, t.mtl)
            end
        end

        if towers and tspec and tspec.m then
            local lat = -span * 0.5
            local p = { x = o.x + fx * fwd + rx * lat,
                        y = o.y + fy * fwd + ry * lat, z = o.z }
            if self.CampSnapToGround then p = self:CampSnapToGround(p) end
            p.z = p.z + (tonumber(self.CastleTowerUp) or tspec.up or 0)
            castleMxSpawn(self, tspec.m, p, yaw + math.rad(self.CastleTowerYaw or 0))
        end

        System.LogAlways(string.format("[Castle] #%-2d at %3.0fm  %-8s %-13s len %5.2f x%d%s  %s",
            i, fwd, t.grp or "?", t.n, len, cnt, t.back and " +back" or "", t.m))
    end

    -- the number logged is the segment's own index, so merc_castle_wall takes it
    -- straight even when the lineup was filtered to one group
    System.LogAlways(string.format(
        "[Castle] %d run(s)%s, %d pieces, %.0fm deep. merc_castle_wall <the # of the row you liked>.",
        #want, grp and (" in " .. grp) or "", n, 14.0 + #want * pitch))
    System.LogAlways("[Castle] groups: " .. self:CastleGroupWords() .. "   merc_castle_matrix_clear removes them")
end

-- merc_castle_rects [group|all|picks] [side] [gap]
-- A closed rectangle of each candidate, laid out in a field you can walk between. The
-- lineup (merc_castle_matrix) answers "what does one piece look like"; this answers the
-- question that actually decides a wall type - how it turns a corner, whether the run
-- reads as one wall or as a row of props, and what the inside face looks like, which on
-- a one-sided mesh is the half nobody checks until the camp is inside it.
--
-- The side is rounded to a whole number of tiles, so a rectangle never shows a seam the
-- real builder would not make. One tile is left out of the near edge as a doorway.
function mercenaries:CastleRects(line)
    local a = {}
    for w in castleArg(line):gmatch("%S+") do a[#a + 1] = w end
    local grp
    if a[1] and not tonumber(a[1]) then grp = string.lower(table.remove(a, 1)) end
    local side = tonumber(a[1]) or 24.0
    local gap  = tonumber(a[2]) or 12.0

    local want = {}
    if not grp or grp == "picks" then
        local byName = {}
        for i, t in ipairs(self.CastleWalls) do byName[t.n] = { i = i, t = t } end
        for _, n in ipairs(self.CastleRectPicks or {}) do
            if byName[n] then table.insert(want, byName[n]) end
        end
    else
        for i, t in ipairs(self.CastleWalls) do
            if grp == "all" or t.grp == grp then table.insert(want, { i = i, t = t }) end
        end
    end
    if #want == 0 then
        System.LogAlways("[Castle] no group called '" .. tostring(grp) .. "' - try: picks, all, "
            .. self:CastleGroupWords())
        return
    end

    self:CastleMatrixClear()
    if not player then return end

    -- Each rectangle is a whole number of its own tiles, so they are all different sizes.
    -- The grid is pitched on the widest one, which keeps the gaps between them even.
    local widest = 0
    for _, w in ipairs(want) do
        local len = math.max(0.1, w.t.len or 2.0)
        -- A wall type with corner meshes spends part of every side on them, so the
        -- tiled span is what is left. Keeping the tile count whole means the sides come
        -- out a little over the asked-for length rather than opening a seam.
        for _, c in ipairs(self:CastleCornerList(w.t) or {}) do
            if math.abs(90 - (c.turn or 0)) < TURN_MIN then w.corner = c end
        end
        local arm = w.corner and (tonumber(self.CastleCornerArm) or 2.00) or 0
        w.cutIn  = w.corner and (w.corner.cutIn  or w.corner.cut or arm) or 0
        w.cutOut = w.corner and (w.corner.cutOut or w.corner.cut or arm) or 0
        -- never fewer than two: one tile a side, minus the doorway, leaves a whole
        -- face of the rectangle missing and nothing to judge the run by
        w.n = math.max(2, math.floor((side - w.cutIn - w.cutOut) / len + 0.5))
        w.side = w.n * len + w.cutIn + w.cutOut
        if w.side > widest then widest = w.side end
    end
    local pitch = widest + gap
    local cols = math.max(1, math.floor(math.sqrt(#want) + 0.5))

    local o = player:GetWorldPos()
    local ang; pcall(function() ang = player:GetWorldAngles() end)
    local pyaw = (ang and ang.z) or 0
    local fx, fy = math.cos(pyaw), math.sin(pyaw)     -- away from the player
    local rx, ry = -fy, fx                            -- to the player's left

    local spawned = 0
    for k, w in ipairs(want) do
        local t = w.t
        local len, ox, lat = math.max(0.1, t.len or 2.0), tonumber(t.ox) or 0, tonumber(t.lat) or 0
        -- the type's OWN yaw, not self.WallYawFix: nothing is selected here, so the
        -- global still holds whatever the last merc_castle_wall left behind
        local yawfix = math.rad(tonumber(t.yaw) or 0)
        local col, row = (k - 1) % cols, math.floor((k - 1) / cols)
        -- the field starts one pitch out and spreads either side of the player's line
        local cf = pitch * (row + 1)
        local cl = pitch * (col - (cols - 1) / 2)
        local cx, cy = o.x + fx * cf + rx * cl, o.y + fy * cf + ry * cl

        local half = w.side / 2
        -- Anticlockwise from the near-right, so every turn is a LEFT one: that is the
        -- hand the corner meshes are cut for, and it puts the outer face of a one-sided
        -- mesh on the outside. Going round the other way turns a wall inside out.
        local corner = {
            { x = cx - fx * half - rx * half, y = cy - fy * half - ry * half },
            { x = cx + fx * half - rx * half, y = cy + fy * half - ry * half },
            { x = cx + fx * half + rx * half, y = cy + fy * half + ry * half },
            { x = cx - fx * half + rx * half, y = cy - fy * half + ry * half },
        }
        local door = math.floor(w.n / 2)      -- a way in, on the near edge

        for e = 1, 4 do
            local p0, p1 = corner[e], corner[(e % 4) + 1]
            local ex, ey = p1.x - p0.x, p1.y - p0.y
            local L = math.sqrt(ex * ex + ey * ey)
            local ux, uy = ex / L, ey / L
            local yaw = math.atan2(uy, ux) + yawfix
            local lx, ly = -uy * lat, ux * lat
            for j = 0, w.n - 1 do
                if not (e == 1 and j == door) then
                    -- the run starts past whatever the corner behind it takes up
                    local d = w.cutOut + (j + 0.5) * len - ox
                    local p = { x = p0.x + ux * d + lx, y = p0.y + uy * d + ly, z = o.z }
                    if self.CampSnapToGround then p = self:CampSnapToGround(p) end
                    p.z = p.z + (t.up or 0)
                    if castleMxSpawn(self, t.m, p, yaw, t.mtl) then spawned = spawned + 1 end
                end
            end
            if w.corner then
                -- stands on p1, the far end of this edge, turning onto the next
                local dx, dy = self:CastleCornerOffset(w.corner, math.atan2(uy, ux))
                local p = { x = p1.x + dx, y = p1.y + dy, z = o.z }
                if self.CampSnapToGround then p = self:CampSnapToGround(p) end
                p.z = p.z + (t.up or 0)
                if castleMxSpawn(self, w.corner.m,
                                 p, math.atan2(uy, ux) + math.rad(w.corner.yaw or 0),
                                 w.corner.mtl or t.mtl) then spawned = spawned + 1 end
            end
        end

        System.LogAlways(string.format(
            "[Castle] #%-2d %-8s %-13s tile %5.2f x%d = %5.1fm square, %4.1fm tall%s",
            w.i, t.grp or "?", t.n, len, w.n, w.side, t.tall or 0,
            w.corner and "  (+ corner pieces)" or "  (butt corners)"))
    end

    System.LogAlways(string.format(
        "[Castle] %d rectangle(s), %d pieces, %.0fm grid. Walk out and round them.",
        #want, spawned, pitch))
    System.LogAlways("[Castle] merc_castle_wall <the # of the one you liked>, then "
        .. "merc_castle_build. merc_castle_matrix_clear removes these.")
end

-- merc_castle_tower_row [wall] [tiles] [gap]
-- Every tower in the survey, stood up in a row with the wall running in from both sides,
-- which is the only way to see the thing that matters: whether its floor lands where the
-- wall walk does, and whether it reads as part of the same wall or as a borrowed prop.
--
-- The wall is whichever type is selected, or named as the first word. Each tower is sunk
-- or raised so that whichever of its floors is nearest the wall's own walk ends up level
-- with it, and the run stops at the tower's own footprint so the two meet rather than
-- interpenetrating.
function mercenaries:CastleTowerRow(line)
    local a = {}
    for w in castleArg(line):gmatch("%S+") do a[#a + 1] = w end
    local wname
    if a[1] and not tonumber(a[1]) then wname = string.lower(table.remove(a, 1)) end
    local tiles = math.max(1, math.floor(tonumber(a[1]) or 2))
    local gap   = tonumber(a[2]) or 10.0

    local wt
    if wname then
        for _, t in ipairs(self.CastleWalls) do if t.n == wname then wt = t end end
        if not wt then
            System.LogAlways("[Castle] no wall called '" .. wname .. "'")
            return
        end
    else
        wt = self.WallTypes[self.WallTypeIdx] or {}
        if not wt.walk then                      -- nothing selected that has a walk
            for _, t in ipairs(self.CastleWalls) do if t.n == "kh_a" then wt = t end end
        end
    end

    self:CastleMatrixClear()
    if not player then return end

    local len  = math.max(0.1, tonumber(wt.len) or 4.0)
    local ox   = tonumber(wt.ox) or 0
    local lat  = tonumber(wt.lat) or 0
    local wyaw = math.rad(tonumber(wt.yaw) or 0)
    -- the walk in WORLD terms: a type sunk on purpose carries its walkway down with it
    local walk = tonumber(wt.walk)
    if walk then walk = walk + (tonumber(wt.up) or 0) end

    local o = player:GetWorldPos()
    local ang; pcall(function() ang = player:GetWorldAngles() end)
    local pyaw = (ang and ang.z) or 0
    local fx, fy = math.cos(pyaw), math.sin(pyaw)     -- the wall runs across your view
    local rx, ry = -fy, fx
    local yaw = math.atan2(ry, rx)

    local pitch = 2 * tiles * len + 2 * gap
    local n = 0
    for k, tw in ipairs(self.CastleTowerSurvey) do
        -- put the deck nearest the wall's walk level with it
        local deck, best
        for _, d in ipairs(tw.decks or {}) do
            local miss = walk and math.abs(d - walk) or -d
            if not best or miss < best then best, deck = miss, d end
        end
        local up = (walk and deck) and (walk - deck) or 0

        local along = (k - 1) * pitch - (#self.CastleTowerSurvey - 1) * pitch / 2
        local base = { x = o.x + fx * 22.0 + rx * along,
                       y = o.y + fy * 22.0 + ry * along, z = o.z }
        if self.CampSnapToGround then base = self:CampSnapToGround(base) end

        local t = { x = base.x, y = base.y, z = base.z + up }
        if castleMxSpawn(self, tw.m, t, yaw, tw.mtl) then n = n + 1 end

        -- the curtain, running in from both sides and stopping on the tower's footprint
        for _, dir in ipairs({ -1, 1 }) do
            for j = 0, tiles - 1 do
                local d = (tw.half or 4.0) + j * len
                local cx = base.x + rx * dir * d
                local cy = base.y + ry * dir * d
                -- the piece is laid running AWAY from the tower on this side
                local ex, ey = rx * dir, ry * dir
                local eyaw = math.atan2(ey, ex) + wyaw
                local p = { x = cx + ex * (len / 2 - ox) - ey * lat,
                            y = cy + ey * (len / 2 - ox) + ex * lat,
                            z = base.z + (tonumber(wt.up) or 0) }
                if castleMxSpawn(self, wt.m, p, eyaw, wt.mtl) then n = n + 1 end
            end
        end

        -- A tower lifted to reach the walk is standing on nothing. Worth saying out
        -- loud, because in the row it just looks like a tall tower until you walk to it.
        local note = ""
        if up > 1.0 then note = string.format("  HOISTED %.1fm - its floor cannot reach", up)
        elseif up < -1.0 then note = string.format("  SUNK %.1fm - %.1fm of it is buried", -up, -up)
        elseif math.abs(up) < 0.26 then note = "  sits as it is" end
        System.LogAlways(string.format(
            "[Castle] %2d from the left / %2d from the right  %-14s %5.1fm tall, "
            .. "%3.1fm half-width, deck %5.2f -> %s%.2fm%s",
            #self.CastleTowerSurvey - k + 1, k, tw.n, tw.tall or 0, tw.half or 0,
            deck or 0, (up >= 0) and "+" or "", up, note))
    end

    System.LogAlways(string.format(
        "[Castle] %d towers with %s, walk %.2fm above ground, %d pieces. "
        .. "merc_castle_matrix_clear removes them.",
        #self.CastleTowerSurvey, wt.n or "?", walk or 0, n))
end

-- merc_castle_square [tiles] [tiles across]
-- An EXACT rectangle, laid out rather than drawn.
--
-- Drawing one by hand cannot come out exact, and not because the snapping is weak: the
-- first edge is marked before there is a corner at its start, and the closing edge is
-- never marked at all - it is whatever is left when the ring shuts. Those two edges get
-- whatever length the shape leaves them, the tiling finds a remainder it cannot use, and
-- the flush fill covers it with a piece laid nearly on top of its neighbour. The other
-- edges are exact.
--
-- So this builds the ring from the grid instead of fitting the grid to a ring. Each side
-- is the corner allowance plus a whole number of tiles, which is the only length that
-- tiles cleanly, and all four corners fall where the pieces expect them.
function mercenaries:CastleSquare(line)
    local a = {}
    for w in castleArg(line):gmatch("%S+") do a[#a + 1] = w end
    local nx = math.max(0, math.floor(tonumber(a[1]) or 4))
    local ny = math.max(0, math.floor(tonumber(a[2]) or nx))

    local wt = self.WallTypes[self.WallTypeIdx] or {}
    if not wt.castle then
        System.LogAlways("[Castle] pick a stone wall first: merc_castle_wall <n>")
        return
    end
    local corner = self:CastleCornerFor(90, wt)
    if not corner then
        System.LogAlways("[Castle] " .. tostring(wt.n) .. " has no corner piece - "
            .. "a square of it would be closed by towers, which need no exact fit")
    end
    local cin  = corner and (tonumber(corner.cutIn)  or tonumber(corner.cut) or 0) or 0
    local cout = corner and (tonumber(corner.cutOut) or tonumber(corner.cut) or 0) or 0
    local step = tonumber(wt.len) or 4.0
    local sx, sy = cin + cout + nx * step, cin + cout + ny * step

    if not player then return end
    local o = player:GetWorldPos()
    local ang; pcall(function() ang = player:GetWorldAngles() end)
    local pyaw = (ang and ang.z) or 0
    -- anticlockwise from the near-right, the hand the corner pieces are cut for
    local fx, fy = math.cos(pyaw), math.sin(pyaw)
    local rx, ry = -fy, fx
    local corners = {}
    for _, uv in ipairs({ { 0, 0 }, { 1, 0 }, { 1, 1 }, { 0, 1 } }) do
        local along, across = uv[1] * sx, uv[2] * sy
        local p = { x = o.x + fx * (6.0 + along) + rx * across,
                    y = o.y + fy * (6.0 + along) + ry * across, z = o.z }
        if self.WallSnap and self.CampSnapToGround then p = self:CampSnapToGround(p) end
        table.insert(corners, p)
    end

    table.insert(self.WallRuns, { pts = corners, closed = true })
    self.WallBaseYaw = nil
    self:WallRebuild()
    pcall(function() if self.DefSave then self:DefSave() end end)
    System.LogAlways(string.format(
        "[Castle] %s: %.2f x %.2f m (%d x %d tiles of %.2f + %.2f m of corner each side)",
        wt.n or "?", sx, sy, nx, ny, step, cin + cout))
end

function mercenaries:CastleGroupWords()
    local seen, out = {}, {}
    for _, t in ipairs(self.CastleWalls) do
        local g = t.grp or "?"
        if not seen[g] then seen[g] = true; table.insert(out, g) end
    end
    return table.concat(out, ", ")
end

mercenaries:DevCommand("merc_castle_build",     "mercenaries:CastleBuild()",
    "Start the castle builder: stone segments, corner towers, a gate of your choosing")
mercenaries:DevCommand("merc_castle_help",      "mercenaries:CastleHelp()",       "List the castle-builder commands")
mercenaries:DevCommand("merc_castle_status",    "mercenaries:CastleStatus()",     "Segment, towers, thickness and gate currently set")
mercenaries:DevCommand("merc_castle_wall",      "mercenaries:CastleSetWall('%line')",  "Stone segment: merc_castle_wall <n> (no arg lists them)")
mercenaries:DevCommand("merc_castle_tower",     "mercenaries:CastleSetTower('%line')", "Corner tower: merc_castle_tower <n>, 1 = none (no arg lists them)")
mercenaries:DevCommand("merc_castle_gate",      "mercenaries:CastleSetGate('%line')",  "Gate the run closes with: merc_castle_gate <n> (no arg lists them)")
mercenaries:DevCommand("merc_castle_towers",    "mercenaries:CastleSetTowers('%line')","Corner towers: 0 or 1")
mercenaries:DevCommand("merc_castle_ends",      "mercenaries:CastleSetEnds('%line')",  "Towers on the open ends of a run too: 0 or 1")
mercenaries:DevCommand("merc_castle_corners",   "mercenaries:CastleSetCorners('%line')", "Corner pieces on the turns without a tower: 0 or 1")
mercenaries:DevCommand("merc_castle_tower_every", "mercenaries:CastleSetTowerEvery('%line')", "A tower every n corners: 1 = every corner, 0 = none")
mercenaries:DevCommand("merc_castle_thick",     "mercenaries:CastleSetThick('%line')", "Wall thickness in metres (the back-face copy); 0 turns it off")
mercenaries:DevCommand("merc_castle_back",      "mercenaries:CastleSetBack('%line')",  "Double the current segment to close a hollow back: 0 or 1")
mercenaries:DevCommand("merc_castle_tower_up",  "mercenaries:CastleSetTowerUp('%line')",  "Raise or sink every tower by N metres")
mercenaries:DevCommand("merc_castle_tower_yaw", "mercenaries:CastleSetTowerYaw('%line')", "Spin every tower by N degrees")
mercenaries:DevCommand("merc_castle_tune",      "mercenaries:CastleTune()",       "Print the fitted segment and tower as table rows")
mercenaries:DevCommand("merc_castle_ghost",     "mercenaries:CastleSetGhost('%line')",
    "Which stone fence the build projection is drawn with (no arg lists them)")
mercenaries:DevCommand("merc_castle_gateway",   "mercenaries:StartCastleGatewayPlacement()",
    "Cut a gateway into the stone wall where you aim (archway tile plus its leaves)")
mercenaries:DevCommand("merc_castle_gateway_probe", "mercenaries:CastleGatewayProbe()",
    "Say where the gateway chain breaks: mark, archway tile, gate record, entity")
mercenaries:DevCommand("merc_castle_gateway_clear", "mercenaries:CastleGatewayClearAll()",
    "Take every gateway out and put plain curtain back")
mercenaries:DevCommand("merc_castle_off",       "mercenaries:CastleOff()",        "Back to the palisade wall type, towers off")
mercenaries:DevCommand("merc_castle_matrix",       "mercenaries:CastleMatrix('%line')",
    "Lay the stone segments out as tiled sample runs: merc_castle_matrix [group|all] [runlength] [rowpitch] [towers 0|1]")
mercenaries:DevCommand("merc_castle_square",       "mercenaries:CastleSquare('%line')",
    "Lay an EXACT rectangle of the current stone wall: merc_castle_square [tiles] [tiles across]")
mercenaries:DevCommand("merc_castle_tower_row",    "mercenaries:CastleTowerRow('%line')",
    "Stand every tower candidate up with the wall running into it: merc_castle_tower_row [wall] [tiles] [gap]")
mercenaries:DevCommand("merc_castle_rects",        "mercenaries:CastleRects('%line')",
    "Build a closed rectangle out of each candidate: merc_castle_rects [group|all|picks] [side] [gap]")
mercenaries:DevCommand("merc_castle_matrix_clear", "mercenaries:CastleMatrixClear()",
    "Remove the sample runs and rectangles")
