"""Read a built SWF back and say what is actually in it.

This exists because every failure in this pipeline is silent. A clip the Lua addresses but
the SWF does not contain produces no error, no log line and no missing-texture marker - it
simply does not draw. The only way to catch it before the game does is to parse the file
you just wrote and compare its instance names against the XML contract and the Lua atlas.
"""
import struct

from . import swf as S


class BitReader:
    def __init__(self, data, off=0):
        self.data, self.pos, self.bit = data, off, 0

    def ub(self, n):
        v = 0
        for _ in range(n):
            byte = self.data[self.pos]
            v = (v << 1) | ((byte >> (7 - self.bit)) & 1)
            self.bit += 1
            if self.bit == 8:
                self.bit = 0
                self.pos += 1
        return v

    def align(self):
        if self.bit:
            self.bit = 0
            self.pos += 1

    def skip_matrix(self):
        if self.ub(1):                              # HasScale
            n = self.ub(5)
            self.ub(n); self.ub(n)
        if self.ub(1):                              # HasRotate
            n = self.ub(5)
            self.ub(n); self.ub(n)
        n = self.ub(5)                              # translate
        self.ub(n); self.ub(n)
        self.align()
        return self.pos


def _place_name(body):
    """The instance name out of a PlaceObject2 body, or None."""
    flags = body[0]
    if not flags & 0x20:                            # HasName
        return None
    off = 3                                         # flags + depth
    if flags & 0x02:                                # HasCharacter
        off += 2
    if flags & 0x04:                                # HasMatrix
        off = BitReader(body, off).skip_matrix()
    if flags & (0x08 | 0x10):
        # ColorTransform / Ratio: never emitted by swf.py, so a file carrying one did not
        # come from here and the offset below would be a guess.
        raise ValueError("PlaceObject2 carries a colour transform or ratio")
    end = body.find(b"\x00", off)
    return body[off:end].decode("ascii", "replace")


def read(path):
    """Parse the top level of a SWF. Sprites are opaque: their inner tags are skipped by
    length, which is what keeps the placeholder name inside each sprite out of the result.
    """
    data = open(path, "rb").read()
    if data[:3] != b"FWS":
        raise ValueError("%s is not an uncompressed SWF (got %r)" % (path, data[:3]))

    r = BitReader(data, 8)
    nb = r.ub(5)
    xmin, xmax, ymin, ymax = (r.ub(nb) for _ in range(4))
    r.align()
    off = r.pos + 4                                 # frame rate + frame count

    counts, names, sprites = {}, [], []
    while off < len(data) - 1:
        (tl,) = struct.unpack("<H", data[off:off + 2])
        off += 2
        code, ln = tl >> 6, tl & 0x3F
        if ln == 0x3F:
            (ln,) = struct.unpack("<i", data[off:off + 4])
            off += 4
        body = data[off:off + ln]
        off += ln
        counts[code] = counts.get(code, 0) + 1
        if code == S.PLACE_OBJECT2:
            n = _place_name(body)
            if n:
                names.append(n)
        elif code == S.DEFINE_SPRITE:
            sid, frames = struct.unpack("<HH", body[:4])
            sprites.append((sid, frames))
        elif code == S.END:
            break

    return {
        "version": data[3],
        "bytes": len(data),
        "declared": struct.unpack("<I", data[4:8])[0],
        "stage": (xmax // S.TWIP, ymax // S.TWIP),
        "tags": counts,
        "names": names,
        "sprites": sprites,
    }


def cross_check(swf_path, xml_path=None, lua_names=None):
    """Every name the Lua can ask for must exist in the SWF *and* in the XML contract.

    Returns a list of complaints; empty means the three agree.
    """
    import re

    info = read(swf_path)
    in_swf = set(info["names"])
    bad = []

    if len(in_swf) != len(info["names"]):
        seen, dupes = set(), set()
        for n in info["names"]:
            if n in seen:
                dupes.add(n)
            seen.add(n)
        bad.append("duplicate instance names in the SWF: %s" % ", ".join(sorted(dupes)))

    if xml_path:
        xml = open(xml_path, encoding="utf-8", errors="replace").read()
        in_xml = set(re.findall(r'instancename="([^"]+)"', xml))
        for n in sorted(in_swf - in_xml):
            bad.append("in the SWF but not declared in the XML: %s" % n)
        for n in sorted(in_xml - in_swf):
            bad.append("declared in the XML but not in the SWF: %s" % n)

    if lua_names:
        for n in sorted(set(lua_names) - in_swf):
            bad.append("the Lua atlas lists a clip the SWF does not have: %s" % n)

    return bad


def describe(path):
    info = read(path)
    out = ["%s" % path,
           "  SWF v%d, %d bytes (header says %d), stage %dx%d"
           % (info["version"], info["bytes"], info["declared"],
              info["stage"][0], info["stage"][1]),
           "  %d named instances, %d sprites" % (len(info["names"]), len(info["sprites"]))]
    for code in sorted(info["tags"]):
        out.append("  tag %-3d %-22s x%d"
                   % (code, S.TAG_NAMES.get(code, "?"), info["tags"][code]))
    multi = [s for s in info["sprites"] if s[1] > 1]
    if multi:
        out.append("  multi-frame sprites: %s"
                   % ", ".join("#%d(%d frames)" % s for s in multi))
    return "\n".join(out)
