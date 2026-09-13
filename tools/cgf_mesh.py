"""Read the geometry out of a KCD2 .cgf/.cgfm pair. No Blender, no game, just bytes.

KCD2 splits a static mesh in two. The `.cgf` is the scene graph - nodes, the material
library name, the physics proxies - and carries no vertices at all (a 1157-vertex crate
is a 1.7 KB file). The vertex and index STREAMS live beside it in a `.cgfm`, which has
its own copy of the node and mesh chunks for the renderable geometry only. So this reads
the `.cgfm` and ignores the `.cgf` except for the material library name.

Both are CryEngine chunk files: "CrCh" + version 0x746 + chunk count + table offset,
then a table of 16-byte entries {type, version, id, size, offset}.

    0x1000  Mesh          vert/index counts, the bbox, and a chunk id per stream
    0x100B  Node          name, transform, which mesh chunk is its geometry
    0x1014  MtlName       the material library path
    0x1016  DataStream    one stream: {flags, type, count, elementSize, reserved[2]}
    0x1017  MeshSubsets   which slice of the index buffer belongs to which submaterial

The stream that matters is type 15, the interleaved 16-byte vertex: three half floats
of position (plus a half of padding), four bytes of colour, two half floats of UV.
Older meshes use separate float streams (0 positions, 2 texcoords) and both are handled.

    python tools/cgf_mesh.py objects/.../crate_short.cgf     # report what is in one
    python tools/cgf_mesh.py --obj out.obj objects/.../x.cgf # dump it as a Wavefront OBJ

See docs/blender-workspace.md.
"""
import glob
import os
import struct
import sys
import zipfile

import numpy as np

PAKS = (r"C:/Program Files/Steam/steamapps/common/KingdomComeDeliverance2/Data/"
        r"IPL_Objects-part*.pak")

CHUNK_MESH, CHUNK_NODE, CHUNK_MTLNAME = 0x1000, 0x100B, 0x1014
CHUNK_STREAM, CHUNK_SUBSETS = 0x1016, 0x1017

STREAM_POSITIONS, STREAM_TEXCOORDS, STREAM_INDICES, STREAM_INTERLEAVED = 0, 2, 5, 15
STREAM_COLORS = 3


class Pak(object):
    """The object paks as one case-insensitive read-only filesystem."""

    def __init__(self, pattern=PAKS):
        self.entries = {}
        self.zips = []
        for path in sorted(glob.glob(pattern)):
            z = zipfile.ZipFile(path)
            self.zips.append(z)
            for name in z.namelist():
                self.entries[name.lower().replace("\\", "/")] = (z, name)

    def __contains__(self, path):
        return path.lower().replace("\\", "/") in self.entries

    def read(self, path):
        hit = self.entries.get(path.lower().replace("\\", "/"))
        if not hit:
            return None
        z, name = hit
        return z.read(name)

    def find(self, *needles, **kw):
        ext = kw.get("ext", ".cgf")
        out = [p for p in self.entries
               if p.endswith(ext) and all(n in p for n in needles)]
        return sorted(out)


def chunks(data):
    """{chunk id: (type, version, offset, size)} for a chunk file, or {} if it is not one."""
    if len(data) < 16 or data[:4] != b"CrCh":
        return {}
    _ver, count, table = struct.unpack_from("<III", data, 4)
    if count > 20000 or table + count * 16 > len(data):
        return {}
    out = {}
    for i in range(count):
        kind, ver, cid, size, off = struct.unpack_from("<HHIII", data, table + i * 16)
        out[cid] = (kind, ver, off, size)
    return out


def _cstr(data, off, length):
    return data[off:off + length].split(b"\0")[0].decode("ascii", "replace")


def read_stream(data, off):
    """(stream type, element size, raw bytes) of one DataStream chunk."""
    _flags, kind, count, esize = struct.unpack_from("<4I", data, off)
    body = off + 24
    return kind, esize, data[body:body + count * esize], count


class Part(object):
    """One node's geometry: a mesh, where it sits, and which submaterial each face uses."""

    def __init__(self, name, verts, uvs, tris, mats, matrix, bbox):
        self.name = name
        self.verts = verts          # (n, 3) float32, metres, Z up
        self.uvs = uvs              # (n, 2) float32 or None
        self.tris = tris            # (m, 3) int32
        self.mats = mats            # (m,) int32 - submaterial index per triangle
        self.matrix = matrix        # 4x4 row-major, the node's own transform
        self.bbox = bbox            # (min xyz, max xyz) as the file states it
        self.colours = None         # (n, 4) uint8 BGRA, or None - alpha drives blending

    def __repr__(self):
        return "<Part %s %d verts %d tris %d mats>" % (
            self.name, len(self.verts), len(self.tris), len(set(self.mats.tolist())))


def _mesh_from_chunk(data, ch, mesh_off, name, matrix):
    ints = struct.unpack_from("<27I", data, mesh_off)
    nverts, nindices, nsubsets, subsets_id = ints[2], ints[3], ints[4], ints[5]
    streams = ints[7:23]
    bbox = struct.unpack_from("<6f", data, mesh_off + 27 * 4)
    if not nverts or not nindices:
        return None

    verts = uvs = colours = None
    inter = streams[STREAM_INTERLEAVED]
    if inter and inter in ch:
        _k, esize, raw, count = read_stream(data, ch[inter][2])
        a = np.frombuffer(raw, dtype=np.float16).reshape(count, esize // 2)
        verts = a[:, 0:3].astype(np.float32)
        # ...x y z pad | colour as 4 bytes | u v...  - the UV is the last pair of halfs
        uvs = a[:, esize // 2 - 2:].astype(np.float32)
        # the four bytes between them are the vertex colour; its ALPHA is what a
        # blend-layer material reads to mix its second layer in
        b = np.frombuffer(raw, dtype=np.uint8).reshape(count, esize)
        # The interleaved element stores a D3D UCol, which is BGRA. Flipped to RGBA here
        # so `colours` means the same thing whichever stream it came out of - see the
        # note on the separate stream below.
        colours = b[:, 8:12][:, [2, 1, 0, 3]].copy()
    else:
        pid = streams[STREAM_POSITIONS]
        if not (pid and pid in ch):
            return None
        _k, esize, raw, count = read_stream(data, ch[pid][2])
        verts = np.frombuffer(raw, dtype=np.float32).reshape(count, esize // 4)[:, :3].copy()
        tid = streams[STREAM_TEXCOORDS]
        if tid and tid in ch:
            _k, es, raw2, c2 = read_stream(data, ch[tid][2])
            dt = np.float16 if es == 4 else np.float32
            uvs = np.frombuffer(raw2, dtype=dt).reshape(c2, -1)[:, :2].astype(np.float32)
        # rc.exe writes our FBX exports as separate streams rather than the interleaved
        # one the shipped meshes use - every one of 300 sampled shipped meshes uses the
        # interleaved form and none uses this one. The two do NOT agree on byte order:
        # the interleaved element is a D3D UCol (BGRA), this stream is CryEngine's
        # SMeshColor (RGBA). Reading both as the same thing hides a red/blue swap that
        # turns warm stone blue, and hides it from every comparison you can make.
        cid = streams[STREAM_COLORS]
        if cid and cid in ch:
            _k, es, raw3, c3 = read_stream(data, ch[cid][2])
            colours = np.frombuffer(raw3, dtype=np.uint8).reshape(c3, es)[:, :4].copy()

    iid = streams[STREAM_INDICES]
    if not (iid and iid in ch):
        return None
    _k, esize, raw, count = read_stream(data, ch[iid][2])
    idx = np.frombuffer(raw, dtype=np.uint16 if esize == 2 else np.uint32).astype(np.int32)
    tris = idx[:(len(idx) // 3) * 3].reshape(-1, 3)

    # Subsets carve the index buffer into runs, one per submaterial. Without them every
    # face lands on slot 0 and a multi-material prop comes in wearing one texture.
    mats = np.zeros(len(tris), dtype=np.int32)
    if subsets_id in ch:
        soff = ch[subsets_id][2]
        _f, scount = struct.unpack_from("<2I", data, soff)
        # 16-byte header, then one 36-byte subset each: five ints, a radius and a centre.
        # The chunk is 4*count bytes longer than that, so deriving the stride from its
        # size reads 40 and every subset after the first comes out as garbage - which
        # lands the whole mesh on submaterial 0 and paints a ladder with its own proxy.
        SUBSET = 36
        for s in range(scount):
            base = soff + 16 + s * SUBSET
            first_i, num_i, _fv, _nv, mat_id = struct.unpack_from("<5i", data, base)
            lo, hi = first_i // 3, (first_i + num_i) // 3
            mats[lo:hi] = mat_id
    part = Part(name, verts, uvs, tris, mats, matrix, (bbox[:3], bbox[3:]))
    part.colours = colours
    return part


def load(pak, path):
    """Every renderable part of one .cgf, plus its material library path.

    `path` is the .cgf as the game names it; the .cgfm beside it is what actually holds
    the geometry. Returns ([Part], material library path or None).
    """
    base = path.lower().replace("\\", "/")
    if base.endswith(".cgfm"):
        base = base[:-1]
    cgf = pak.read(base)
    data = pak.read(base + "m")
    if data is None:                       # a mesh small enough to keep its streams inline
        data = cgf
    if data is None:
        return [], None

    mtl = None
    for src in (cgf, data):
        if not src:
            continue
        for kind, _v, off, size in chunks(src).values():
            if kind == CHUNK_MTLNAME:
                mtl = _cstr(src, off, min(size, 260))
                break
        if mtl:
            break

    ch = chunks(data)
    parts = []
    for cid, (kind, _ver, off, _size) in sorted(ch.items()):
        if kind != CHUNK_NODE:
            continue
        name = _cstr(data, off, 64)
        object_id = struct.unpack_from("<i", data, off + 64)[0]
        tm = np.array(struct.unpack_from("<16f", data, off + 84), dtype=np.float32)
        tm = tm.reshape(4, 4)
        if object_id in ch and ch[object_id][0] == CHUNK_MESH:
            part = _mesh_from_chunk(data, ch, ch[object_id][2], name, tm)
            if part:
                parts.append(part)
    return parts, mtl


def bbox_of(pak, path):
    """(min, max) over every part, straight from the file headers - no geometry needed."""
    parts, _ = load(pak, path)
    if not parts:
        return None
    lo = np.min([p.bbox[0] for p in parts], axis=0)
    hi = np.max([p.bbox[1] for p in parts], axis=0)
    return lo, hi


def write_obj(parts, out):
    with open(out, "w") as f:
        base = 1
        for p in parts:
            f.write("o %s\n" % (p.name or "part"))
            for v in p.verts:
                f.write("v %.5f %.5f %.5f\n" % tuple(v))
            if p.uvs is not None:
                for t in p.uvs:
                    f.write("vt %.5f %.5f\n" % (t[0], 1.0 - t[1]))
            for tri in p.tris:
                a, b, c = (tri + base).tolist()
                if p.uvs is not None:
                    f.write("f %d/%d %d/%d %d/%d\n" % (a, a, b, b, c, c))
                else:
                    f.write("f %d %d %d\n" % (a, b, c))
            base += len(p.verts)


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    out = None
    if "--obj" in sys.argv:
        out = sys.argv[sys.argv.index("--obj") + 1]
        args = [a for a in args if a != out]
    pak = Pak()
    for path in args:
        if path not in pak:
            hits = pak.find(*path.split())
            print("%s -> %d match(es)" % (path, len(hits)))
            for h in hits[:10]:
                print("   ", h)
            continue
        parts, mtl = load(pak, path)
        lo, hi = bbox_of(pak, path) or (None, None)
        print("%s\n  mtl %s\n  %d part(s)  bbox %s .. %s  size %s"
              % (path, mtl, len(parts),
                 np.round(lo, 3) if lo is not None else "?",
                 np.round(hi, 3) if hi is not None else "?",
                 np.round(hi - lo, 3) if lo is not None else "?"))
        for p in parts:
            print("   ", p)
        if out:
            write_obj(parts, out)
            print("  -> %s" % out)


if __name__ == "__main__":
    main()
