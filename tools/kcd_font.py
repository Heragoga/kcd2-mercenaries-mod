"""Render text in the game's own UI typefaces.

KCD2's interface fonts are Warhorse originals - "Kingdom Come Regular" for body copy and
"Kingdom Come Display Md Display" for headings - and they ship only inside the Scaleform font
library, not as .ttf files. Libs/UI/gfxfontlib.gfx carries the metrics with the outlines
stripped; the outlines live in Libs/UI/gfxfontlib_glyphs.gfx. Both are zlib'd GFX ("CFX")
containers holding ordinary SWF DefineFont3 tags, so the glyphs can be read straight out and
rasterised here. That is what makes the mod's panels sit next to the vanilla ones instead of
looking like a mod. See docs/ui.md.

    import kcd_font
    img = kcd_font.text("Camp", 40, (235, 224, 200), font="display")
"""
import os
import struct
import zipfile
import zlib

import numpy
from PIL import Image, ImageDraw

GAME = r"C:\Program Files\Steam\steamapps\common\KingdomComeDeliverance2\Data"
PAK = os.path.join(GAME, "IPL_GameData.pak")
GLYPHS = "Libs/UI/gfxfontlib_glyphs.gfx"

# fontconfig.xml maps the engine's logical names onto these
FACES = {
    "body":    ("Kingdom Come Regular", False),
    "bold":    ("Kingdom Come Regular", True),
    "display": ("Kingdom Come Display Md Display", False),
    "light":   ("Kingdom Light Regular", False),
}
EM = 1024 * 20          # DefineFont3 coordinates are twips of a 1024-unit em
SS = 4                  # supersample used while filling contours

_cache = {}


class _Bits(object):
    def __init__(self, buf):
        self.b, self.p, self.bit = buf, 0, 0

    def u(self, n):
        v = 0
        for _ in range(n):
            v = (v << 1) | ((self.b[self.p] >> (7 - self.bit)) & 1)
            self.bit += 1
            if self.bit == 8:
                self.bit, self.p = 0, self.p + 1
        return v

    def s(self, n):
        if n == 0:
            return 0
        v = self.u(n)
        return v - (1 << n) if v & (1 << (n - 1)) else v


def _tags(raw):
    o = (5 + (raw[0] >> 3) * 4 + 7) // 8 + 4        # frame RECT, rate, count
    while o < len(raw) - 1:
        th, = struct.unpack_from("<H", raw, o)
        o += 2
        code, ln = th >> 6, th & 0x3F
        if ln == 0x3F:
            ln, = struct.unpack_from("<I", raw, o)
            o += 4
        yield code, raw[o:o + ln]
        o += ln
        if code == 0:
            break


def _shape(buf):
    """One glyph's SHAPE record as a list of closed contours of points."""
    r = _Bits(buf)
    nfill, nline = r.u(4), r.u(4)
    contours, cur = [], []
    x = y = 0
    while True:
        if r.u(1) == 0:                              # style change / end
            flags = r.u(5)
            if flags == 0:
                break
            if flags & 0x01:                         # StateMoveTo
                n = r.u(5)
                if cur:
                    contours.append(cur)
                x, y = r.s(n), r.s(n)
                cur = [(x, y)]
            if flags & 0x02:
                r.u(nfill)
            if flags & 0x04:
                r.u(nfill)
            if flags & 0x08:
                r.u(nline)
            if flags & 0x10:                         # StateNewStyles - not in glyphs
                break
        elif r.u(1):                                 # straight edge
            n = r.u(4) + 2
            if r.u(1):
                dx, dy = r.s(n), r.s(n)
            elif r.u(1):
                dx, dy = 0, r.s(n)
            else:
                dx, dy = r.s(n), 0
            x, y = x + dx, y + dy
            cur.append((x, y))
        else:                                        # quadratic
            n = r.u(4) + 2
            cx, cy = x + r.s(n), y + r.s(n)
            ax, ay = cx + r.s(n), cy + r.s(n)
            x0, y0 = x, y
            for i in range(1, 9):                    # flatten
                t = i / 8.0
                m = 1 - t
                cur.append((m * m * x0 + 2 * m * t * cx + t * t * ax,
                            m * m * y0 + 2 * m * t * cy + t * t * ay))
            x, y = ax, ay
    if cur:
        contours.append(cur)
    return contours


def face(name="body"):
    """Glyph contours + advances for one face, keyed by character."""
    if name in _cache:
        return _cache[name]
    want, want_bold = FACES[name]
    raw = zlib.decompress(zipfile.ZipFile(PAK).read(GLYPHS)[8:])
    for code, body in _tags(raw):
        if code != 75:
            continue
        flags, nlen = body[2], body[4]
        nm = body[5:5 + nlen].decode("latin-1").rstrip("\0")
        if nm != want or bool(flags & 0x01) != want_bold or flags & 0x02:
            continue
        p = 5 + nlen
        ng, = struct.unpack_from("<H", body, p)
        p += 2
        wide = bool(flags & 0x08)
        step, fmt = (4, "<I") if wide else (2, "<H")
        offs = [struct.unpack_from(fmt, body, p + i * step)[0] for i in range(ng + 1)]
        ct = p + offs[ng]
        codes = [struct.unpack_from("<H", body, ct + i * 2)[0] for i in range(ng)]
        lay = ct + ng * 2
        asc, desc, _lead = struct.unpack_from("<3h", body, lay)
        adv = [struct.unpack_from("<h", body, lay + 6 + i * 2)[0] for i in range(ng)]
        f = {"asc": asc, "desc": desc, "g": {}}
        for i, ch in enumerate(codes):
            f["g"][chr(ch)] = (_shape(body[p + offs[i]:p + offs[i + 1]]), adv[i])
        _cache[name] = f
        return f
    raise KeyError("face not in the game font library: %s" % name)


def measure(s, px, font="body", tracking=0.0):
    f = face(font)
    k = px / float(EM)
    w = sum(f["g"].get(c, f["g"][" "])[1] for c in s) * k + tracking * max(0, len(s) - 1)
    return int(round(w)), int(round((f["asc"] + f["desc"]) * k))


def text(s, px, rgb, font="body", tracking=0.0):
    """Rasterise a string. Returns RGBA sized to the face's ascent+descent box."""
    f = face(font)
    k = px / float(EM)
    w, h = measure(s, px, font, tracking)
    if w <= 0 or h <= 0:
        return Image.new("RGBA", (1, 1), (0, 0, 0, 0))
    size = ((w + 2) * SS, h * SS)
    acc = numpy.zeros((size[1], size[0]), dtype=bool)
    lay = Image.new("1", size, 0)
    dr = ImageDraw.Draw(lay)
    pen = 0.0
    for c in s:
        glyph, adv = f["g"].get(c, f["g"][" "])
        for pts in glyph:
            if len(pts) < 3:
                continue
            # Even-odd: XOR each contour in, so a counter punches through its letter.
            dr.rectangle([0, 0, size[0], size[1]], fill=0)
            dr.polygon([((pen + x * k) * SS, (f["asc"] + y) * k * SS) for x, y in pts], fill=1)
            acc ^= numpy.asarray(lay)
        pen += adv * k + tracking
    a = Image.fromarray((acc * 255).astype(numpy.uint8)).resize((w + 2, h), Image.LANCZOS)
    out = Image.new("RGBA", (w + 2, h), rgb + (0,))
    out.putalpha(a)
    return out
