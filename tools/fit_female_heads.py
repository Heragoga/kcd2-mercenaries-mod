"""Lift the vanilla female head and hair meshes onto the male skeleton.

THE PROBLEM. A female head skin mounted in the Male component tree binds and renders - that
much is proven in game - but it renders about 7 cm too low, sunk into the collar. The cause is
not a bug and not a scale error: the mesh is authored around the FEMALE skeleton's Head joint,
and the female skeleton is shorter than the male one.

Read out of the CompiledBones chunk (type 0x2000) of each .skin, the bind translation of the
joint called "Head":

    male    (0.0000,  0.0039, 1.5542)
    female  (0.0000, -0.0185, 1.4834)
    delta   (0.0000,  0.0224, 0.0708)

and the engine plainly renders the vertices at their authored heights (a female head's mesh
bounding box sits at z 1.3061..1.6284 against a male head's 1.4019..1.7298). There is no XML
lever for this: across the whole of vanilla CharacterComponent.xml a <SkinElement> only ever
carries EquipmentPart, Material, Model, BodyLayerId, KeepBodyLayer and IsFinalLayer. No
position, no offset, no scale.

THE FIX. Translate the mesh and write it out under our own name.

Z comes from the NECK SEAM, not from the joint. The first build used the joint delta (0.0707)
on the theory that helmets hang off the Head joint and a joint-aligned head keeps its headgear
fitting; in game that landed visibly low, and by eye "a few centimetres" short. The seam delta
- male head bbox z-min minus female head bbox z-min, 1.4019 - 1.3061 = 0.0958 - is exactly
25 mm more, and 25 mm is what the eye asked for. The two measurements agree, so the seam wins:
what a viewer actually reads is where the jaw and neck meet the collar, and all fifty female
heads in the game share one bounding box (z-min 1.3061 to four decimals, no spread at all), so
one constant fits every head.

X and Y still come from the joint delta - nothing suggests the depth is wrong, and "line up
the back of the skull" is not a meaningful target the way a neck seam is.

The cost of the seam over the joint: headgear, which hangs off the Head joint, now sits about
25 mm low relative to the face. Female mercs are bare-headed by default (merc_female_helmets),
so that only shows with the switch turned on.

WHY THIS IS SAFE TO DO ARITHMETICALLY. Positions in a KCD2 .skin are plain little-endian
float32 triples, so every edit here is in place and the same size as what it replaces - the
chunk table never moves and never needs rebuilding. Three places hold a position:

  * stream chunk 0x1016 with stream type 0 - 24-byte header, then nCount * 12 bytes;
  * 0x2005 CompiledIntSkinVertices - 32-byte header, then 64-byte records with the position
    at +12 (the Vec3s at +0 and +24 are the obsolete ones and are all zero);
  * 0x1000 mesh chunk - the bounding box, six floats at +108.

Every one of those is checked arithmetically before it is touched (header + count * stride
must equal the chunk length exactly), and the tool refuses the file rather than guessing.

OUTPUT GOES TO OUR OWN PATHS. Never write over humans/female/... - those meshes are worn by
986 vanilla female NPCs, and shifting them would lift every woman in Bohemia 7 cm into the
air. Materials are NOT copied: the .mtl files reference their own textures as "./x.tif", so a
copy in a new folder would lose them. CharacterComponent__mercenaries.xml keeps FilePath on
the vanilla female directory (so Material stays a plain sibling filename) and reaches out to
the shifted mesh with a relative Model path.

Usage:
    python tools/fit_female_heads.py              # regenerate everything
    python tools/fit_female_heads.py --dz 0.085   # try a different lift
    python tools/fit_female_heads.py --report     # measure only, write nothing

See docs/female-mercenaries.md.
"""
import argparse
import os
import struct
import sys
import zipfile

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_ROOT = os.path.join(REPO, 'data', 'Objects', 'characters', 'humans', 'male')

CH_MESH = 0x1000
CH_STREAM = 0x1016
CH_SKINVERTS = 0x2005
CH_BONES = 0x2000

STREAM_HDR = 24
SKINVERT_HDR = 32
SKINVERT_STRIDE = 64
SKINVERT_POS_OFF = 12
MESH_BBOX_OFF = 108
BONE_HDR = 32
BONE_STRIDE = 584
BONE_NAME_OFF = 312
BONE_B2W_OFF = 264

# name in our tree            -> vanilla asset, relative to Objects/characters/
HEADS = [
    ('merc_fhead_01', 'humans/female/head/f_head_009/f_head_009'),
    ('merc_fhead_02', 'humans/female/head/f_head_002/f_head_002'),
    ('merc_fhead_03', 'humans/female/head/f_head_015/f_head_015'),
    ('merc_fhead_04', 'humans/female/head/f_head_019/f_head_019'),
    ('merc_fhead_05', 'humans/female/head/f_head_021/f_head_021'),
    ('merc_fhead_06', 'humans/female/head/f_head_030/f_head_030'),
    ('merc_fhead_07', 'humans/female/head/f_head_034/f_head_034'),
    ('merc_fhead_08', 'humans/female/head/f_head_036/f_head_036'),
    ('merc_fhead_09', 'humans/female/head/f_head_041/f_head_041'),
    ('merc_fhead_10', 'humans/female/head/f_head_047/f_head_047'),
]
HAIRS = [
    ('merc_fhair_a', 'humans/female/hair/f_hair_01/f_hair_01'),
    ('merc_fhair_b', 'humans/female/hair/f_hair_02/f_hair_02'),
    ('merc_fhair_c', 'humans/female/hair/f_hair_03/f_hair_03'),
    ('merc_fhair_d', 'humans/female/hair/f_hair_04/f_hair_04'),
    ('merc_fhair_e', 'humans/female/hair/f_hair_05/f_hair_05'),
    ('merc_fhair_f', 'humans/female/hair/f_hair_06/f_hair_06'),
    ('merc_fhair_g', 'humans/female/hair/f_hair_07/f_hair_07'),
]


def find_game():
    """Same resolution order as tools/Find-KCD2.ps1 and tools/facial_retarget.py: the game
    path is a per-machine question and is never hardcoded (see docs, and the note in
    tools/facial_retarget.py)."""
    env = os.environ.get('KCD2_DIR')
    if env and os.path.isdir(env):
        return env
    local = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'local.paths.txt')
    if os.path.isfile(local):
        with open(local, encoding='utf-8', errors='replace') as f:
            for line in f:
                line = line.strip()
                if line.startswith('#') or '=' not in line:
                    continue
                k, v = line.split('=', 1)
                if k.strip().lower() == 'game':
                    v = v.strip().strip('"')
                    if os.path.isdir(v):
                        return v
    for guess in (r'C:\Program Files (x86)\Steam\steamapps\common\KingdomComeDeliverance2',
                  r'C:\Program Files\Steam\steamapps\common\KingdomComeDeliverance2'):
        if os.path.isdir(guess):
            return guess
    return None


class Paks(object):
    """Every .pak in Data, indexed once by lowercased internal path."""

    def __init__(self, game):
        self.zips = {}
        self.index = {}
        data = os.path.join(game, 'Data')
        for fn in sorted(os.listdir(data)):
            if not fn.endswith('.pak'):
                continue
            try:
                z = zipfile.ZipFile(os.path.join(data, fn))
            except Exception:
                continue
            self.zips[fn] = z
            for n in z.namelist():
                self.index.setdefault(n.replace('\\', '/').lower(), (fn, n))

    def read(self, path):
        hit = self.index.get(path.lower())
        if not hit:
            return None
        fn, n = hit
        return self.zips[fn].read(n)


def chunk_table(buf):
    """(type, version, id, offset, end) per chunk, sorted by offset. A chunk's length is
    implied by where the next one starts, which is why this returns end as well."""
    if buf[:5] != b'CrChF':
        raise ValueError('not a CrChF chunk file')
    count = struct.unpack_from('<I', buf, 8)[0]
    table = struct.unpack_from('<I', buf, 12)[0]
    ents = [struct.unpack_from('<IIII', buf, table + 16 * i) for i in range(count)]
    ents.sort(key=lambda e: e[3])
    out = []
    for i, (t, v, cid, off) in enumerate(ents):
        end = ents[i + 1][3] if i + 1 < len(ents) else len(buf)
        out.append((t & 0xFFFF, v, cid, off, end))
    return out


def head_joint(buf):
    """Bind translation of the joint named "Head", from the CompiledBones chunk."""
    for t, v, cid, off, end in chunk_table(buf):
        if t != CH_BONES:
            continue
        n = (end - off - BONE_HDR) // BONE_STRIDE
        for k in range(n):
            r = off + BONE_HDR + k * BONE_STRIDE
            name = buf[r + BONE_NAME_OFF:r + BONE_NAME_OFF + 256].split(b'\0')[0]
            if name == b'Head':
                m = struct.unpack_from('<12f', buf, r + BONE_B2W_OFF)
                return (m[3], m[7], m[11])
    return None


def bbox(buf):
    for t, v, cid, off, end in chunk_table(buf):
        if t == CH_MESH:
            return struct.unpack_from('<6f', buf, off + MESH_BBOX_OFF)
    return None


def shift(buf, dx, dy, dz):
    """Translate every position in a .skin. Returns (newbuf, notes)."""
    out = bytearray(buf)
    notes = []
    for t, v, cid, off, end in chunk_table(buf):
        size = end - off

        if t == CH_STREAM:
            # 24-byte header: the stream type is the 2nd uint32, count the 3rd, stride the 4th.
            _, stype, count, stride, _ = struct.unpack_from('<5I', buf, off)
            if stype != 0:
                continue
            if stride != 12 or STREAM_HDR + count * stride != size:
                raise ValueError('position stream %d: header+%d*%d != %d'
                                 % (cid, count, stride, size))
            base = off + STREAM_HDR
            for i in range(count):
                p = base + i * 12
                x, y, z = struct.unpack_from('<3f', buf, p)
                struct.pack_into('<3f', out, p, x + dx, y + dy, z + dz)
            notes.append('positions x%d' % count)

        elif t == CH_SKINVERTS:
            if (size - SKINVERT_HDR) % SKINVERT_STRIDE:
                raise ValueError('skin verts %d: %d is not 32 + n*64' % (cid, size))
            count = (size - SKINVERT_HDR) // SKINVERT_STRIDE
            base = off + SKINVERT_HDR
            for i in range(count):
                p = base + i * SKINVERT_STRIDE + SKINVERT_POS_OFF
                x, y, z = struct.unpack_from('<3f', buf, p)
                struct.pack_into('<3f', out, p, x + dx, y + dy, z + dz)
            notes.append('skinverts x%d' % count)

        elif t == CH_MESH:
            b = struct.unpack_from('<6f', buf, off + MESH_BBOX_OFF)
            # Sanity: a head or a hairstyle is a small box somewhere up a standing figure.
            if not (all(-3 < c < 3 for c in b)
                    and b[0] < b[3] and b[1] < b[4] and b[2] < b[5]):
                raise ValueError('mesh chunk %d: %r does not look like a bbox' % (cid, b))
            struct.pack_into('<6f', out, off + MESH_BBOX_OFF,
                             b[0] + dx, b[1] + dy, b[2] + dz,
                             b[3] + dx, b[4] + dy, b[5] + dz)
            notes.append('bbox')

    if not any(n.startswith('positions') for n in notes):
        raise ValueError('no position stream found')
    return bytes(out), notes


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--dx', type=float, default=None)
    ap.add_argument('--dy', type=float, default=None)
    ap.add_argument('--dz', type=float, default=None)
    ap.add_argument('--report', action='store_true', help='measure only, write nothing')
    args = ap.parse_args()

    game = find_game()
    if not game:
        print('Kingdom Come Deliverance 2 not found. Set KCD2_DIR, or add a game= line to '
              'tools/local.paths.txt.')
        return 1
    print('game: %s' % game)
    paks = Paks(game)

    # The delta is MEASURED from the two skeletons unless it is overridden, so a game patch
    # that moves either rig is picked up rather than silently ignored.
    male = paks.read('Objects/characters/humans/male/head/m_head_081/m_head_081.skin')
    female = paks.read('Objects/characters/humans/female/head/f_head_009/f_head_009.skin')
    if not male or not female:
        print('reference heads missing from the paks')
        return 1
    mj, fj = head_joint(male), head_joint(female)
    mb, fb = bbox(male), bbox(female)
    print('Head joint  male=(%.4f, %.4f, %.4f)  female=(%.4f, %.4f, %.4f)'
          % (mj[0], mj[1], mj[2], fj[0], fj[1], fj[2]))
    print('bbox z      male=%.4f..%.4f  female=%.4f..%.4f' % (mb[2], mb[5], fb[2], fb[5]))
    print('            joint dz %.4f   seam dz %.4f   (seam is %.0f mm higher)'
          % (mj[2] - fj[2], mb[2] - fb[2], (mb[2] - fb[2] - (mj[2] - fj[2])) * 1000))
    # x/y from the joint, z from the neck seam - see the note at the top of the file.
    dx = args.dx if args.dx is not None else mj[0] - fj[0]
    dy = args.dy if args.dy is not None else mj[1] - fj[1]
    dz = args.dz if args.dz is not None else mb[2] - fb[2]
    print('delta       (%.4f, %.4f, %.4f)%s'
          % (dx, dy, dz, '  [overridden]' if (args.dx, args.dy, args.dz) != (None, None, None) else ''))

    if args.report:
        print('shifted     z %.4f .. %.4f  against male %.4f .. %.4f'
              % (fb[2] + dz, fb[5] + dz, mb[2], mb[5]))
        return 0

    total = written = 0
    for name, src in HEADS + HAIRS:
        sub = 'head' if name.startswith('merc_fhead') else 'hair'
        outdir = os.path.join(OUT_ROOT, sub, name)
        for suffix in ('', '_LOD1', '_LOD2'):
            spath = 'Objects/characters/%s%s.skin' % (src, suffix)
            buf = paks.read(spath)
            if buf is None:
                if suffix == '':
                    print('  MISSING %s' % spath)
                continue
            total += 1
            try:
                new, notes = shift(buf, dx, dy, dz)
            except ValueError as e:
                print('  FAIL %s%s: %s' % (name, suffix, e))
                continue
            if not os.path.isdir(outdir):
                os.makedirs(outdir)
            dst = os.path.join(outdir, name + suffix + '.skin')
            with open(dst, 'wb') as f:
                f.write(new)
            written += 1
            nb = bbox(new)
            print('  %-16s %-6s %8d B  z %.4f..%.4f  [%s]'
                  % (name, suffix or 'LOD0', len(new), nb[2], nb[5], ', '.join(notes)))

    print('\n%d/%d meshes written under data/Objects/characters/humans/male/' % (written, total))
    return 0


if __name__ == '__main__':
    sys.exit(main())
