"""Rewrite the material library path inside a compiled .cgf.

rc.exe's FBX path always writes the library name as `default`, whatever `/mtl` says. An
unresolvable library is not just a cosmetic problem: the engine reads the submaterials to
learn which faces are the `Nodraw` physics proxy, so a .cgf that cannot find its .mtl
gets no collision at all.

This rewrites the MtlName chunk (0x1014) with the real path. The version 0x802 name
occupies a fixed 128-byte field, followed by the submaterial count. The
whole file is re-emitted with the chunk table's offsets recomputed - the layout is
header(16) + table(count * 16) + payloads, in table order. The magic is "CrCh"; the F of
"CrChF" is just the low byte of version 0x746.

    python tools/cgf_setmtl.py <file.cgf> objects/mercenaries/walls/merc_castle_stone
    python tools/cgf_setmtl.py <file.cgf> --show
"""
import struct
import sys

HEADER = 16
ENTRY = 16
CHUNK_MTLNAME = 0x1014
ALIGN = 4
NUL = bytes([0])


def read(path):
    data = open(path, "rb").read()
    if data[:4] != b"CrCh":
        raise SystemExit("%s is not a CrCh chunk file" % path)
    version, count, table = struct.unpack_from("<III", data, 4)
    chunks = []
    for i in range(count):
        kind, ver, cid, size, off = struct.unpack_from("<HHIII", data, table + i * ENTRY)
        chunks.append({"type": kind, "ver": ver, "id": cid,
                       "payload": data[off:off + size]})
    return version, chunks


def library_of(payload):
    return payload.split(NUL, 1)[0].decode("ascii", "replace")


def set_library(payload, name):
    """Preserve the fixed 128-byte name field of MtlName version 0x802."""
    encoded = name.encode("ascii")
    if len(encoded) >= 128:
        raise ValueError("Material library path must fit the 128-byte field")
    if len(payload) < 132:
        raise ValueError("Truncated MtlName payload")
    tail = payload[128:]
    if struct.unpack_from('<I', tail)[0] == 0:
        # Recover files written by the previous implementation, which replaced
        # 'default\0' while retaining its 120 padding bytes and shifted the tail.
        old_end = payload.index(NUL) + 1
        displaced = old_end + 120
        if displaced + 4 <= len(payload):
            count = struct.unpack_from('<I', payload, displaced)[0]
            names_at = displaced + 4 + 4 * count
            if 0 < count < 256 and names_at < len(payload):
                names = payload[names_at:].split(NUL)
                if len(names) == count + 1 and names[-1] == b'' and all(names[:-1]):
                    tail = payload[displaced:]
    return encoded.ljust(128, NUL) + tail


def write(path, version, chunks):
    count = len(chunks)
    offset = HEADER + count * ENTRY
    entries, body = [], []
    for c in chunks:
        pad = (-offset) % ALIGN
        if pad:
            body.append(NUL * pad)
            offset += pad
        entries.append(struct.pack("<HHIII", c["type"], c["ver"], c["id"],
                                   len(c["payload"]), offset))
        body.append(c["payload"])
        offset += len(c["payload"])
    header = b"CrCh" + struct.pack("<III", version, count, HEADER)
    open(path, "wb").write(header + b"".join(entries) + b"".join(body))


def main():
    if len(sys.argv) < 3:
        raise SystemExit(__doc__)
    path, arg = sys.argv[1], sys.argv[2]
    version, chunks = read(path)
    mtl = [c for c in chunks if c["type"] == CHUNK_MTLNAME]
    if not mtl:
        raise SystemExit("no MtlName chunk in %s" % path)
    if arg == "--show":
        for c in mtl:
            print("library: %s" % library_of(c["payload"]))
        return
    before = library_of(mtl[0]["payload"])
    for c in mtl:
        if c['ver'] != 0x802:
            raise SystemExit('Unsupported MtlName version: %x' % c['ver'])
        c["payload"] = set_library(c["payload"], arg)
    write(path, version, chunks)
    again = [c for c in read(path)[1] if c["type"] == CHUNK_MTLNAME]
    check = library_of(again[0]["payload"])
    print("%s: %r -> %r" % (path, before, check))
    if check != arg:
        raise SystemExit("patch did not take")


if __name__ == "__main__":
    main()
