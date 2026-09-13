"""Generate a SWF v8 / AS2 movie for KCD2's Scaleform UI.

Why this exists: the disassembly proved the engine will load a plain `.swf` in place of a
Scaleform-compiled `.gfx` when `wh_gfx_useSWF` is set (see docs/ui.md). That removes the need
for the discontinued Scaleform exporter - but only if we can *produce* a SWF. This does, with
no dependencies.

The movie it writes is deliberately dumb: a set of solid rectangles placed on the root, each
with a PlaceObject2 instance NAME. It contains no ActionScript at all. That is the
`LockPicking.gfx` pattern - vanilla's lockpicking movie declares zero functions and is driven
entirely from outside by moving its named clips - so everything is controlled from Lua via
UIAction.SetPos / SetScale / SetRotation / SetAlpha / SetVisible.

One named rectangle is a primitive we never had: a real filled rectangle, at any position,
size, rotation and opacity. The whole ASCII-underscore panel hack exists only because we
lacked it.

    python tools/make_swf.py                 write the default test movie
    python tools/make_swf.py --verify FILE   parse a SWF back and list its tags + named clips

SWF reference: the format is bit-packed; RECT/MATRIX/shape records are written MSB-first via
BitWriter. Coordinates are twips (1/20 px).
"""
import struct, sys, os

TWIP = 20


class BitWriter:
    def __init__(self):
        self.buf = bytearray()
        self.cur = 0
        self.nbits = 0

    def ub(self, value, bits):
        for i in range(bits - 1, -1, -1):
            self.cur = (self.cur << 1) | ((value >> i) & 1)
            self.nbits += 1
            if self.nbits == 8:
                self.buf.append(self.cur)
                self.cur = 0
                self.nbits = 0

    def sb(self, value, bits):
        if value < 0:
            value = (1 << bits) + value
        self.ub(value, bits)

    def align(self):
        if self.nbits:
            self.cur <<= (8 - self.nbits)
            self.buf.append(self.cur)
            self.cur = 0
            self.nbits = 0

    def bytes(self):
        self.align()
        return bytes(self.buf)


def sbits_needed(*values):
    n = 1
    for v in values:
        v = int(v)
        b = 1
        while True:
            lo = -(1 << (b - 1))
            hi = (1 << (b - 1)) - 1
            if lo <= v <= hi:
                break
            b += 1
        n = max(n, b)
    return n


def rect(xmin, xmax, ymin, ymax):
    """RECT in twips."""
    vals = [int(xmin), int(xmax), int(ymin), int(ymax)]
    nb = sbits_needed(*vals)
    w = BitWriter()
    w.ub(nb, 5)
    for v in vals:
        w.sb(v, nb)
    return w.bytes()


def matrix(tx, ty):
    """MATRIX with translation only."""
    w = BitWriter()
    w.ub(0, 1)                      # HasScale
    w.ub(0, 1)                      # HasRotate
    nb = sbits_needed(int(tx), int(ty))
    w.ub(nb, 5)
    w.sb(int(tx), nb)
    w.sb(int(ty), nb)
    return w.bytes()


def tag(code, body):
    if len(body) < 0x3F:
        return struct.pack("<H", (code << 6) | len(body)) + body
    return struct.pack("<H", (code << 6) | 0x3F) + struct.pack("<i", len(body)) + body


def define_shape_rect(shape_id, w_px, h_px, rgb):
    """DefineShape (tag 2): one solid rectangle with its top-left at the origin."""
    w, h = int(w_px * TWIP), int(h_px * TWIP)
    body = struct.pack("<H", shape_id)
    body += rect(0, w, 0, h)

    b = BitWriter()
    b.ub(1, 8)                      # FillStyleCount = 1
    b.align()
    fills = bytes([0x00]) + bytes(rgb)   # solid fill, RGB

    s = BitWriter()
    s.ub(0, 8)                      # LineStyleCount = 0
    s.ub(1, 4)                      # NumFillBits = 1
    s.ub(0, 4)                      # NumLineBits = 0
    # StyleChangeRecord: move to origin, select fill style 1
    s.ub(0, 1)                      # TypeFlag = non-edge
    s.ub(0, 1)                      # StateNewStyles
    s.ub(0, 1)                      # StateLineStyle
    s.ub(1, 1)                      # StateFillStyle1
    s.ub(0, 1)                      # StateFillStyle0
    s.ub(1, 1)                      # StateMoveTo
    mb = sbits_needed(0, 0)
    s.ub(mb, 5); s.sb(0, mb); s.sb(0, mb)
    s.ub(1, 1)                      # FillStyle1 = 1 (NumFillBits = 1)
    # four straight edges around the rectangle
    for dx, dy in ((w, 0), (0, h), (-w, 0), (0, -h)):
        nb = sbits_needed(dx, dy)
        nb = max(nb, 2)
        s.ub(1, 1)                  # TypeFlag = edge
        s.ub(1, 1)                  # StraightFlag
        s.ub(nb - 2, 4)             # NumBits
        s.ub(1, 1)                  # GeneralLineFlag
        s.sb(dx, nb)
        s.sb(dy, nb)
    # EndShapeRecord
    s.ub(0, 1); s.ub(0, 5)
    return tag(2, body + bytes([0x01]) + fills + s.bytes())


def do_action_stop():
    """DoAction (tag 12) holding a single ActionStop.

    Without this the one-frame timeline LOOPS, and every loop re-executes the PlaceObject2
    tags below - which re-place each clip at its authored matrix and wipe whatever
    UIAction.SetPos/SetScale just did. The symptom is a UI that appears for a moment and then
    snaps back. ActionStop = 0x07, terminated by a 0x00 end-of-actions byte.
    """
    return tag(12, bytes([0x07, 0x00]))


def place(char_id, depth, name, tx_px, ty_px):
    """PlaceObject2 (tag 26) with a character, a matrix and an instance NAME.

    The name is what UIAction addresses: the UIElements XML maps a friendly MovieClip name
    onto this instance name.
    """
    flags = 0x20 | 0x04 | 0x02      # HasName | HasMatrix | HasCharacter
    body = bytes([flags]) + struct.pack("<H", depth) + struct.pack("<H", char_id)
    body += matrix(tx_px * TWIP, ty_px * TWIP)
    body += name.encode("ascii") + b"\x00"
    return tag(26, body)


def define_sprite(sprite_id, shape_id):
    """DefineSprite (tag 39): a one-frame clip wrapping a shape.

    Wrapping matters - UIAction.SetScale/SetRotation act on a MovieClip, and a bare shape is
    not one. This is why every driveable vanilla clip is a sprite.
    """
    inner = place(shape_id, 1, "s", 0, 0) + do_action_stop() + tag(1, b"") + tag(0, b"")
    return tag(39, struct.pack("<HH", sprite_id, 1) + inner)


def build(path, cells=48, stage_w=1280, stage_h=720, version=8, file_attrs=True,
          big=False):
    """A grid of named rectangles: mc_00 .. mc_NN, all driveable from Lua.

    version/file_attrs exist to bisect what Scaleform will accept: SWF 8 requires a
    FileAttributes tag as the very first tag, SWF 6 predates it entirely.
    """
    tags = bytearray()
    if file_attrs and version >= 8:
        tags += tag(69, struct.pack("<I", 0))    # FileAttributes: AS2, no network
    tags += tag(9, bytes((10, 10, 12)))          # SetBackgroundColor
    if big:
        # one large rectangle, centred, no sprite wrapper complexity - the minimal case
        tags += define_shape_rect(1, 600, 300, (220, 190, 90))
        tags += define_sprite(1000, 1)
        tags += place(1000, 1, "mc_00", 300, 200)
        tags += do_action_stop()
        tags += tag(1, b"")
        tags += tag(0, b"")
        header_rest = rect(0, stage_w * TWIP, 0, stage_h * TWIP)
        header_rest += struct.pack("<H", 24 << 8)
        header_rest += struct.pack("<H", 1)
        body = header_rest + bytes(tags)
        swf = b"FWS" + bytes([version]) + struct.pack("<I", 8 + len(body)) + body
        with open(path, "wb") as f:
            f.write(swf)
        return swf, ["mc_00"]

    palette = [(220, 190, 90), (200, 200, 195), (150, 128, 74),
               (219, 74, 48), (120, 160, 200), (140, 140, 140)]
    names = []
    shape_id, sprite_id, depth = 1, 1000, 1
    for i in range(cells):
        col = palette[i % len(palette)]
        tags += define_shape_rect(shape_id, 100, 20, col)
        tags += define_sprite(sprite_id, shape_id)
        nm = "mc_%02d" % i
        # stacked off to one side; Lua positions them for real
        tags += place(sprite_id, depth, nm, 20, 20 + i * 2)
        names.append(nm)
        shape_id += 1
        sprite_id += 1
        depth += 1

    tags += do_action_stop()                      # do not loop - see do_action_stop()
    tags += tag(1, b"")                           # ShowFrame
    tags += tag(0, b"")                           # End

    header_rest = rect(0, stage_w * TWIP, 0, stage_h * TWIP)
    header_rest += struct.pack("<H", 24 << 8)     # frame rate 24 fps (8.8 fixed)
    header_rest += struct.pack("<H", 1)           # frame count
    body = header_rest + bytes(tags)
    total = 8 + len(body)
    swf = b"FWS" + bytes([version]) + struct.pack("<I", total) + body

    with open(path, "wb") as f:
        f.write(swf)
    return swf, names


# ---------------------------------------------------------------- bitmaps

def matrix_full(sx, sy, tx, ty):
    """MATRIX with scale and translation. Scale is FIXED16 (16.16)."""
    w = BitWriter()
    w.ub(1, 1)                                  # HasScale
    sxf, syf = int(round(sx * 65536)), int(round(sy * 65536))
    nb = sbits_needed(sxf, syf)
    w.ub(nb, 5)
    w.sb(sxf, nb)
    w.sb(syf, nb)
    w.ub(0, 1)                                  # HasRotate
    nt = sbits_needed(int(tx), int(ty))
    w.ub(nt, 5)
    w.sb(int(tx), nt)
    w.sb(int(ty), nt)
    return w.bytes()


def define_bits_lossless2(char_id, img):
    """DefineBitsLossless2 (tag 36), format 5 = 32-bit ARGB, zlib compressed.

    The SWF spec stores these pixels ALPHA-PREMULTIPLIED, so a half-transparent red is
    (128, 128, 0, 0) not (128, 255, 0, 0). Getting that wrong shows up as washed-out edges
    rather than an outright failure, which is hard to spot.
    """
    import zlib
    img = img.convert("RGBA")
    w, h = img.size
    out = bytearray()
    for (r, g, b, a) in img.getdata():
        out += bytes((a, (r * a) // 255, (g * a) // 255, (b * a) // 255))
    body = struct.pack("<HBHH", char_id, 5, w, h) + zlib.compress(bytes(out), 9)
    return tag(36, body), w, h


def define_shape_bitmap(shape_id, bitmap_id, w_px, h_px, smoothed=True):
    """A rectangle filled with a bitmap, sized 1:1 to the image.

    Bitmap fills map one image pixel to 20 twips, so the fill matrix scales by 20 to land
    the image at its natural size.
    """
    w, h = int(w_px * TWIP), int(h_px * TWIP)
    body = struct.pack("<H", shape_id) + rect(0, w, 0, h)

    fill_type = 0x41 if smoothed else 0x43      # clipped bitmap
    fills = bytes([0x01, fill_type]) + struct.pack("<H", bitmap_id)
    fills += matrix_full(TWIP, TWIP, 0, 0)

    s = BitWriter()
    s.ub(0, 8)                                  # LineStyleCount
    s.ub(1, 4)                                  # NumFillBits
    s.ub(0, 4)                                  # NumLineBits
    s.ub(0, 1); s.ub(0, 1); s.ub(0, 1); s.ub(1, 1); s.ub(0, 1); s.ub(1, 1)
    mb = sbits_needed(0, 0)
    s.ub(mb, 5); s.sb(0, mb); s.sb(0, mb)
    s.ub(1, 1)                                  # FillStyle1 = 1
    for dx, dy in ((w, 0), (0, h), (-w, 0), (0, -h)):
        nb = max(sbits_needed(dx, dy), 2)
        s.ub(1, 1); s.ub(1, 1); s.ub(nb - 2, 4); s.ub(1, 1)
        s.sb(dx, nb); s.sb(dy, nb)
    s.ub(0, 1); s.ub(0, 5)
    return tag(2, body + fills + s.bytes())


def test_image(w=256, h=128):
    """A pattern with obvious orientation, an alpha gradient and fine detail, so a wrong
    channel order, a flipped row order or broken alpha are all visible at a glance."""
    from PIL import Image, ImageDraw
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    for x in range(w):                          # left->right alpha ramp over a colour ramp
        a = int(255 * x / (w - 1))
        d.line([(x, 0), (x, h)], fill=(220, 190, 90, a))
    d.rectangle([0, 0, w - 1, h - 1], outline=(255, 255, 255, 255), width=3)
    d.rectangle([8, 8, 40, 40], fill=(219, 74, 48, 255))        # RED marks TOP-LEFT
    d.rectangle([w - 41, h - 41, w - 9, h - 9], fill=(60, 120, 220, 255))  # BLUE bottom-right
    for i in range(0, w, 16):                   # fine stripes catch filtering problems
        d.line([(i, h - 8), (i, h - 1)], fill=(255, 255, 255, 255))
    return im


def build_image(path, image=None, stage_w=1280, stage_h=720, version=8):
    """One named clip, mc_img, filled with an embedded bitmap."""
    from PIL import Image
    img = Image.open(image) if image else test_image()
    tags = bytearray()
    tags += tag(69, struct.pack("<I", 0))
    tags += tag(9, bytes((10, 10, 12)))
    bits, iw, ih = define_bits_lossless2(1, img)
    tags += bits
    tags += define_shape_bitmap(2, 1, iw, ih)
    tags += define_sprite(1000, 2)
    tags += place(1000, 1, "mc_img", 100, 100)
    tags += do_action_stop()
    tags += tag(1, b"")
    tags += tag(0, b"")
    header = rect(0, stage_w * TWIP, 0, stage_h * TWIP)
    header += struct.pack("<H", 24 << 8) + struct.pack("<H", 1)
    body = header + bytes(tags)
    swf = b"FWS" + bytes([version]) + struct.pack("<I", 8 + len(body)) + body
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(swf)
    return swf, ["mc_img"], (iw, ih)


TAGNAMES = {0: "End", 1: "ShowFrame", 2: "DefineShape", 9: "SetBackgroundColor",
            26: "PlaceObject2", 39: "DefineSprite", 69: "FileAttributes", 12: "DoAction", 36: "DefineBitsLossless2"}


def verify(path):
    data = open(path, "rb").read()
    print("signature %s  version %d  declared len %d  actual %d"
          % (data[:3].decode(), data[3], struct.unpack("<I", data[4:8])[0], len(data)))
    if data[:3] != b"FWS":
        print("  NOT an uncompressed SWF"); return
    # skip RECT
    nb = data[8] >> 3
    bits = 5 + 4 * nb
    off = 8 + (bits + 7) // 8
    off += 4                                       # frame rate + count
    counts, names = {}, []
    while off < len(data) - 1:
        (tl,) = struct.unpack("<H", data[off:off + 2]); off += 2
        code, ln = tl >> 6, tl & 0x3F
        if ln == 0x3F:
            (ln,) = struct.unpack("<i", data[off:off + 4]); off += 4
        body = data[off:off + ln]; off += ln
        counts[code] = counts.get(code, 0) + 1
        if code == 26 and len(body) > 5 and (body[0] & 0x20):
            z = body.find(b"\x00", 5)
            if z > 0:
                nm = body[body.rfind(b"\x00", 0, z - 1) + 1:z] if False else None
        if code == 0:
            break
    for c, n in sorted(counts.items()):
        print("  tag %-3d %-20s x%d" % (c, TAGNAMES.get(c, "?"), n))


def write_xml(path, element, movie, names, layer=36):
    """The UIElements contract. Generated beside the SWF so the clip names cannot drift.

    Declared movie is `<movie>.gfx`: with wh_gfx_useSWF set the loader strips "gfx" and
    appends "swf", so the .gfx name is what must appear here even though we ship a .swf.
    """
    nl = chr(10)
    clips = nl.join(
        '      <MovieClip name="%s" instancename="%s" />' % (n, n) for n in names)
    xml = """<UIElements name="%s">

  <UIElement name="%s" layer="%d" mouseevents="0" keyevents="0" cursor="0">

    <GFx file="%s.gfx" layer="%d">
      <Constraints>
        <Align mode="fullscreen" />
      </Constraints>
    </GFx>

    <functions>
    </functions>

    <events>
    </events>

    <MovieClips>
%s
    </MovieClips>

  </UIElement>

</UIElements>
""" % (element, element, layer, movie, layer, clips)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="ascii") as f:
        f.write(xml)
    return len(names)


if __name__ == "__main__":
    if "--verify" in sys.argv:
        verify(sys.argv[sys.argv.index("--verify") + 1]); sys.exit(0)
    if "--image" in sys.argv:
        i = sys.argv.index("--image")
        src = sys.argv[i + 1] if len(sys.argv) > i + 1 and not sys.argv[i + 1].startswith("-") else None
        dst = sys.argv[1] if len(sys.argv) > 1 and not sys.argv[1].startswith("-") else "data/libs/UI/MercImg.swf"
        swf, names, size = build_image(dst, src)
        write_xml(os.path.join(os.path.dirname(dst), "UIElements", "MercImg.xml"),
                  "MercImg", "MercImg", names)
        print("wrote %s (%d bytes) from %s, image %dx%d"
              % (dst, len(swf), src or "the built-in test pattern", size[0], size[1]))
        sys.exit(0)
    out = sys.argv[1] if len(sys.argv) > 1 else "data/libs/UI/MercUI.swf"
    os.makedirs(os.path.dirname(out), exist_ok=True)
    swf, names = build(out)
    print("wrote %s  (%d bytes, %d named clips: %s .. %s)"
          % (out, len(swf), len(names), names[0], names[-1]))
    xml = os.path.join(os.path.dirname(out), "UIElements", "MercUI.xml")
    n = write_xml(xml, "MercUI", "MercUI", names)
    print("wrote %s  (%d MovieClips declared)" % (xml, n))
