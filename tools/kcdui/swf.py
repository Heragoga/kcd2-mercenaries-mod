"""A SWF v8 writer, sized for KCD2's Scaleform UI and nothing else.

KCD2 loads a plain uncompressed `.swf` in place of a Scaleform-compiled `.gfx` when
`wh_gfx_useSWF` is set, which is what makes custom UI possible at all without the
discontinued Scaleform exporter. This writes that SWF, with no dependencies beyond Pillow
for the bitmaps.

The movies it produces contain **no ActionScript** beyond a single `stop()`. Everything is
driven from Lua through `UIAction` by addressing PlaceObject2 instance names. That is the
vanilla `LockPicking.gfx` pattern: a movie that declares no functions and is moved entirely
from outside.

Coordinates are twips (1/20 px) and the format is bit-packed MSB-first, which is what
`BitWriter` is for. Nothing here is general-purpose SWF: it writes exactly the five tags a
UI atlas needs.
"""
import struct
import zlib

TWIP = 20

# Tag codes, for readability and for verify.py.
END, SHOW_FRAME, DEFINE_SHAPE = 0, 1, 2
DO_ACTION, PLACE_OBJECT2, REMOVE_OBJECT2 = 12, 26, 28
DEFINE_BITS_LOSSLESS2, DEFINE_SPRITE, FRAME_LABEL = 36, 39, 43
SET_BACKGROUND_COLOR, FILE_ATTRIBUTES = 9, 69

TAG_NAMES = {
    END: "End", SHOW_FRAME: "ShowFrame", DEFINE_SHAPE: "DefineShape",
    DO_ACTION: "DoAction", PLACE_OBJECT2: "PlaceObject2",
    REMOVE_OBJECT2: "RemoveObject2", DEFINE_BITS_LOSSLESS2: "DefineBitsLossless2",
    DEFINE_SPRITE: "DefineSprite", FRAME_LABEL: "FrameLabel",
    SET_BACKGROUND_COLOR: "SetBackgroundColor", FILE_ATTRIBUTES: "FileAttributes",
}


class BitWriter:
    """MSB-first bit packer. SWF's RECT, MATRIX and shape records are all bit fields."""

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
        while not (-(1 << (b - 1)) <= v <= (1 << (b - 1)) - 1):
            b += 1
        n = max(n, b)
    return n


def rect(xmin, xmax, ymin, ymax):
    vals = [int(xmin), int(xmax), int(ymin), int(ymax)]
    nb = sbits_needed(*vals)
    w = BitWriter()
    w.ub(nb, 5)
    for v in vals:
        w.sb(v, nb)
    return w.bytes()


def matrix(sx=None, sy=None, tx=0, ty=0):
    """MATRIX. Scale is FIXED16; pass sx=None for a translation-only matrix."""
    w = BitWriter()
    if sx is None:
        w.ub(0, 1)
    else:
        w.ub(1, 1)
        sxf, syf = int(round(sx * 65536)), int(round((sy if sy is not None else sx) * 65536))
        nb = sbits_needed(sxf, syf)
        w.ub(nb, 5)
        w.sb(sxf, nb)
        w.sb(syf, nb)
    w.ub(0, 1)                                      # HasRotate
    nt = sbits_needed(int(tx), int(ty))
    w.ub(nt, 5)
    w.sb(int(tx), nt)
    w.sb(int(ty), nt)
    return w.bytes()


def tag(code, body):
    if len(body) < 0x3F:
        return struct.pack("<H", (code << 6) | len(body)) + body
    return struct.pack("<H", (code << 6) | 0x3F) + struct.pack("<i", len(body)) + body


def do_action_stop():
    """DoAction holding one ActionStop.

    Without it a one-frame timeline LOOPS, and every loop re-runs the PlaceObject2 tags,
    which re-place each clip at its authored matrix and wipe whatever UIAction.SetPos just
    did. The symptom is a UI that appears for a moment and then snaps back to nothing.
    """
    return tag(DO_ACTION, bytes([0x07, 0x00]))


# ---------------------------------------------------------------- shapes

def _shape_rect_edges(w, h):
    s = BitWriter()
    s.ub(0, 8)                                      # LineStyleCount
    s.ub(1, 4)                                      # NumFillBits
    s.ub(0, 4)                                      # NumLineBits
    # StyleChangeRecord: move to origin and select fill 1
    s.ub(0, 1); s.ub(0, 1); s.ub(0, 1); s.ub(1, 1); s.ub(0, 1); s.ub(1, 1)
    mb = sbits_needed(0, 0)
    s.ub(mb, 5); s.sb(0, mb); s.sb(0, mb)
    s.ub(1, 1)
    for dx, dy in ((w, 0), (0, h), (-w, 0), (0, -h)):
        nb = max(sbits_needed(dx, dy), 2)
        s.ub(1, 1); s.ub(1, 1); s.ub(nb - 2, 4); s.ub(1, 1)
        s.sb(dx, nb); s.sb(dy, nb)
    s.ub(0, 1); s.ub(0, 5)                          # EndShapeRecord
    return s.bytes()


def define_shape_solid(shape_id, w_px, h_px, rgb):
    """A solid-colour rectangle with its top-left at the origin."""
    w, h = int(w_px * TWIP), int(h_px * TWIP)
    body = struct.pack("<H", shape_id) + rect(0, w, 0, h)
    fills = bytes([0x01, 0x00]) + bytes(rgb)        # one style, solid RGB
    return tag(DEFINE_SHAPE, body + fills + _shape_rect_edges(w, h))


def define_bits_lossless2(char_id, img):
    """DefineBitsLossless2, format 5 = 32-bit ARGB, zlib compressed.

    SWF stores these pixels ALPHA-PREMULTIPLIED, so a half-transparent red is
    (128, 128, 0, 0) and not (128, 255, 0, 0). Getting it wrong looks like washed-out
    edges rather than an outright failure, which is why it survives a casual look.
    """
    img = img.convert("RGBA")
    w, h = img.size
    out = bytearray()
    for (r, g, b, a) in img.getdata():
        out += bytes((a, (r * a) // 255, (g * a) // 255, (b * a) // 255))
    body = struct.pack("<HBHH", char_id, 5, w, h) + zlib.compress(bytes(out), 9)
    return tag(DEFINE_BITS_LOSSLESS2, body), w, h


def define_shape_bitmap(shape_id, bitmap_id, w_px, h_px, smoothed=True):
    """A rectangle filled with a bitmap at its natural size.

    Bitmap fills map one image pixel to one twip, so the fill matrix scales by TWIP to
    land the image 1:1.
    """
    w, h = int(w_px * TWIP), int(h_px * TWIP)
    body = struct.pack("<H", shape_id) + rect(0, w, 0, h)
    fills = bytes([0x01, 0x41 if smoothed else 0x43]) + struct.pack("<H", bitmap_id)
    fills += matrix(TWIP, TWIP, 0, 0)
    return tag(DEFINE_SHAPE, body + fills + _shape_rect_edges(w, h))


# ---------------------------------------------------------------- placement

def place(char_id, depth, name=None, sx=None, sy=None, tx=0, ty=0, move=False):
    """PlaceObject2 with a character, a matrix and optionally an instance NAME.

    The instance name is what UIAction addresses; the UIElements XML maps a friendly
    MovieClip name onto it. Coordinates are TWIPS here, not pixels.
    """
    flags = 0x04 | 0x02                             # HasMatrix | HasCharacter
    if name:
        flags |= 0x20
    if move:
        flags |= 0x01
    body = bytes([flags]) + struct.pack("<H", depth) + struct.pack("<H", char_id)
    body += matrix(sx, sy, tx, ty)
    if name:
        body += name.encode("ascii") + b"\x00"
    return tag(PLACE_OBJECT2, body)


def remove(depth):
    return tag(REMOVE_OBJECT2, struct.pack("<H", depth))


def frame_label(name):
    """FrameLabel, which is what makes UIAction.GotoAndStopFrameName addressable."""
    return tag(FRAME_LABEL, name.encode("ascii") + b"\x00")


def define_sprite(sprite_id, frames, ox=0, oy=0, loop=False):
    """DefineSprite: a MovieClip wrapping one shape per frame.

    Wrapping matters - UIAction.SetScale/SetRotation/GotoAndStop act on a MovieClip, and a
    bare shape is not one, which is why every driveable vanilla clip is a sprite.

    `frames` is a list of (shape_id, label_or_None). One frame is the common case. Several
    frames give a clip whose look Lua can swap with GotoAndStopFrameName instead of needing
    one instance per state - and with `loop=True`, a clip that animates on its own once
    GotoAndPlay starts it.

    (ox, oy) is the registration offset in TWIPS: pass the negative half-size to register a
    clip at its middle.
    """
    inner = bytearray()
    for i, (shape_id, label) in enumerate(frames):
        if label:
            inner += frame_label(label)
        if i:
            inner += remove(1)
        inner += place(shape_id, 1, "s" if i == 0 else None, None, None, ox, oy)
        if i == 0 and not loop:
            # Hold frame 1 until Lua asks for another. A sprite that free-runs is almost
            # never what a UI wants, and it costs a frame of CPU per clip per tick.
            inner += do_action_stop()
        inner += tag(SHOW_FRAME, b"")
    inner += tag(END, b"")
    return tag(DEFINE_SPRITE, struct.pack("<HH", sprite_id, len(frames)) + bytes(inner))


# ---------------------------------------------------------------- the file

def movie(tags, stage_w=1280, stage_h=720, fps=24):
    """Wrap a tag stream in an uncompressed SWF v8 header."""
    body = rect(0, stage_w * TWIP, 0, stage_h * TWIP)
    body += struct.pack("<H", fps << 8) + struct.pack("<H", 1)
    body += bytes(tags) + do_action_stop() + tag(SHOW_FRAME, b"") + tag(END, b"")
    return b"FWS" + bytes([8]) + struct.pack("<I", 8 + len(body)) + body


def header_tags(bg=(10, 10, 12)):
    """FileAttributes is required for SWF 8; the background never shows through a UI
    overlay but Scaleform wants the tag present."""
    return tag(FILE_ATTRIBUTES, struct.pack("<I", 0)) + tag(SET_BACKGROUND_COLOR, bytes(bg))
