"""Build larger map-marker icons from vanilla ones.

STATUS: NOT IN USE. The mod ships no icons of its own - mercenaries_mapmarker.lua passes
vanilla icon names. A first attempt at 128x128 custom art drew markers with NO TEXTURE at
all, and this file exists so the next attempt starts from what was learned rather than from
scratch. Do not wire its output into MapMarkerRows until a marker has actually been seen to
render in game.

Why the first attempt failed
----------------------------
Not the route, the files. Pillow's pixel_format="BC3" writes a DX10 header that is not a
loadable texture:

    field         vanilla camp_icon        Pillow "BC3"
    dxgiFormat    98  (BC7_UNORM)          76  (BC3_TYPELESS)
    arraySize     1                        0            <- invalid, D3D requires >= 1
    flags         0x1007                   0x81007      <- claims DDSD_LINEARSIZE...
    pitch         0                        524          <- ...with a wrong value

Two separate faults: a TYPELESS format, and arraySize 0. Stock icons are BC7_UNORM, which
Pillow cannot write at all ("cannot write pixel format BC7").

What this writes instead
------------------------
Legacy DXT5 - fourcc in the old header, no DX10 extension block, so none of the fields above
can be got wrong. DXT5 is BC3, which CryEngine has read since forever. 64x64 comes out at
4224 bytes against vanilla's 4244 (the difference is exactly the 20-byte DX10 block).

If DXT5 also fails to render, the remaining options are, in order: write the DX10 header by
hand with dxgiFormat 77 (BC3_UNORM) and arraySize 1 over Pillow's BC3 payload; or compress
to real BC7 with an external tool (texconv, or the game's own resource compiler) - note that
references/ddv_hc_map_marker ships both a .dds and the .tif it was built from, which is the
shape of an RC-compiled asset.

Sizing
------
A POI's rendered size comes from the movie's scale and the texture's native size. The scale
is not available to us: PoiMarker.SetScale asks GetPoiImportance(type) and only a FIXED list
of vanilla names gets POI_IMPORTANCE_HIGH (PoiTipster, QuestGiver, ActivityGiver, Hub,
DLC0..3, FastTravel*, Nest); joining it would mean shipping a texture under one of those
names and replacing the vanilla icon everywhere. So the texture is the lever. Every stock
map icon is 64x64, quest markers included - a quest marker looks bigger only because its own
class scales it. ddv_hc_map_marker's 100x100 icon renders proportionally larger, which is
what says native size is honoured.

Usage:  python tools/gen_map_icons.py [scale] [--verify]
"""
import os
import struct
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
SRC = os.path.join(REPO, "references", "base_game", "Libs", "UI", "Textures", "icons", "Map")
DST = os.path.join(REPO, "data", "Libs", "UI", "Textures", "Icons", "Map")

# ours <- vanilla art it is built from
ICONS = [
    ("merccamp", "camp"),              # the camp: the vanilla tents
    ("mercwait", "weaponsmiths"),      # men told to wait: crossed blades
    ("mercaleksej", "poiTipster"),     # Aleksej: the vanilla tipster pin
]


def describe(path):
    """Print the header fields that decide whether the engine will load it."""
    d = open(path, "rb").read()
    _, flags, h, w, pitch, _, mips = struct.unpack("<7I", d[4:32])
    fourcc = d[84:88]
    line = "%-28s %dx%d flags=%#x pitch=%d mips=%d fourcc=%s" % (
        os.path.basename(path), w, h, flags, pitch, mips, fourcc.decode("latin1"))
    if fourcc == b"DX10":
        dxgi, _, _, arr, misc2 = struct.unpack("<5I", d[128:148])
        line += " dxgi=%d arraySize=%d misc2=%d" % (dxgi, arr, misc2)
    print("  " + line + "  (%d bytes)" % len(d))


def build(scale):
    if not os.path.isdir(SRC):
        raise SystemExit("vanilla icons not found at " + SRC)
    if not os.path.isdir(DST):
        os.makedirs(DST)

    made = 0
    for ours, vanilla in ICONS:
        for suffix in ("_icon", "_sh_icon"):
            src = os.path.join(SRC, vanilla + suffix + ".dds")
            if not os.path.isfile(src):
                print("  MISSING %s - skipped" % os.path.basename(src))
                continue
            im = Image.open(src).convert("RGBA")
            w, h = im.size
            # BC3/DXT5 works in 4x4 blocks, so keep each dimension a multiple of 4
            nw = max(4, int(round(w * scale / 4.0)) * 4)
            nh = max(4, int(round(h * scale / 4.0)) * 4)
            im = im.resize((nw, nh), Image.LANCZOS)
            out = os.path.join(DST, ours + suffix + ".dds")
            im.save(out, pixel_format="DXT5")
            describe(out)
            made += 1
    print("%d file(s) written to %s" % (made, DST))
    print("Vanilla, for comparison:")
    describe(os.path.join(SRC, "camp_icon.dds"))


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if a != "--verify"]
    if "--verify" in sys.argv:
        for name in sorted(os.listdir(DST)) if os.path.isdir(DST) else []:
            describe(os.path.join(DST, name))
        describe(os.path.join(SRC, "camp_icon.dds"))
        raise SystemExit(0)
    s = float(args[0]) if args else 2.0
    print("Building map icons at %.2fx vanilla size (legacy DXT5)" % s)
    build(s)
