"""Build a Scaleform UI atlas for KCD2: one .swf holding every panel, icon and label as a
separately named MovieClip, plus the matching UIElements XML.

This is the general form of tools/make_swf.py's experiment. Anything the UI needs is declared
as an item, becomes a shape (solid colour or embedded bitmap) wrapped in a sprite, and is
placed with an instance name. Lua then positions, scales, rotates and fades each one - see
docs/ui.md. Nothing here needs ActionScript, a Scaleform licence or an authoring tool.

Three item kinds:
    rect   a solid colour rectangle              -> panels, bars, rules, highlights
    image  an embedded bitmap (PIL image)        -> icons, crests, portraits
    text   a string rasterised with a real font  -> labels, headings, numbers

Text is rasterised rather than drawn with SWF font tags on purpose: it gives real
typography (any installed font, antialiased, kerned) for a fraction of the complexity, and a
label is just another bitmap clip afterwards.

    python tools/make_ui.py --demo      build a small demo atlas and report what is in it
"""
import os, sys, struct

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_swf as M

FONT_SERIF = r"C:\Windows\Fonts\georgia.ttf"
FONT_SERIF_BOLD = r"C:\Windows\Fonts\georgiab.ttf"


# ---------------------------------------------------------------- text -> bitmap

def render_text(text, px=28, rgb=(235, 228, 210), font=None, bold=False, pad=2):
    """Rasterise a string to a tight RGBA image."""
    from PIL import Image, ImageDraw, ImageFont
    path = font or (FONT_SERIF_BOLD if bold else FONT_SERIF)
    f = ImageFont.truetype(path, px)
    probe = ImageDraw.Draw(Image.new("RGBA", (8, 8)))
    l, t, r, b = probe.textbbox((0, 0), text, font=f)
    w, h = max(1, r - l + pad * 2), max(1, b - t + pad * 2)
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(im).text((pad - l, pad - t), text, font=f, fill=tuple(rgb) + (255,))
    return im


# ---------------------------------------------------------------- icons

def icon_canvas(size=64):
    from PIL import Image
    return Image.new("RGBA", (size, size), (0, 0, 0, 0))


def icon_infantry(size=64, rgb=(235, 228, 210)):
    """A shield silhouette - the class read at a glance, not a detailed drawing."""
    from PIL import ImageDraw
    im = icon_canvas(size)
    d = ImageDraw.Draw(im)
    c = tuple(rgb) + (255,)
    w, h = size, size
    # a heater shield: straight shoulders, curved sides meeting at a point
    pts = [(w * 0.16, h * 0.12), (w * 0.84, h * 0.12)]
    for i in range(1, 25):
        t = i / 24.0
        x = w * (0.84 - 0.34 * t * t)
        y = h * (0.12 + 0.80 * t)
        pts.append((x, y))
    for i in range(24, 0, -1):
        t = i / 24.0
        x = w * (0.16 + 0.34 * t * t)
        y = h * (0.12 + 0.80 * t)
        pts.append((x, y))
    d.polygon(pts, fill=c)
    return im


def icon_archer(size=64, rgb=(235, 228, 210)):
    """A bow and arrow."""
    from PIL import ImageDraw
    im = icon_canvas(size)
    d = ImageDraw.Draw(im)
    c = tuple(rgb) + (255,)
    s = size
    lw = max(3, s // 14)
    # the bow limb, drawn as a thick arc opening to the right
    d.arc([s * 0.10, s * 0.06, s * 0.78, s * 0.94], start=292, end=68, fill=c, width=lw)
    # bowstring, tip to tip
    d.line([(s * 0.36, s * 0.10), (s * 0.36, s * 0.90)], fill=c, width=max(2, lw // 2))
    # nocked arrow across the string
    d.line([(s * 0.22, s * 0.50), (s * 0.88, s * 0.50)], fill=c, width=max(2, lw - 1))
    d.polygon([(s * 0.96, s * 0.50), (s * 0.78, s * 0.40), (s * 0.78, s * 0.60)], fill=c)
    d.line([(s * 0.22, s * 0.42), (s * 0.30, s * 0.50)], fill=c, width=max(2, lw - 2))
    d.line([(s * 0.22, s * 0.58), (s * 0.30, s * 0.50)], fill=c, width=max(2, lw - 2))
    return im


def icon_cavalry(size=64, rgb=(235, 228, 210)):
    """A horse-head silhouette."""
    from PIL import ImageDraw
    im = icon_canvas(size)
    d = ImageDraw.Draw(im)
    c = tuple(rgb) + (255,)
    s = size
    d.polygon([(s * 0.30, s * 0.92), (s * 0.30, s * 0.46), (s * 0.40, s * 0.28),
               (s * 0.36, s * 0.12), (s * 0.50, s * 0.20), (s * 0.62, s * 0.12),
               (s * 0.64, s * 0.30), (s * 0.80, s * 0.44), (s * 0.74, s * 0.60),
               (s * 0.56, s * 0.56), (s * 0.52, s * 0.92)], fill=c)
    return im


def icon_chevron(size=64, rgb=(235, 228, 210), direction="up"):
    """A chevron - movement orders read as direction more than as objects."""
    from PIL import ImageDraw
    im = icon_canvas(size)
    d = ImageDraw.Draw(im)
    c = tuple(rgb) + (255,)
    s = size
    pts = [(s * 0.5, s * 0.16), (s * 0.90, s * 0.56), (s * 0.74, s * 0.56),
           (s * 0.5, s * 0.36), (s * 0.26, s * 0.56), (s * 0.10, s * 0.56)]
    if direction == "down":
        pts = [(x, s - y) for (x, y) in pts]
    d.polygon(pts, fill=c)
    pts2 = [(x, y + s * 0.28) for (x, y) in pts] if direction == "up" else \
           [(x, y - s * 0.28) for (x, y) in pts]
    d.polygon(pts2, fill=c)
    return im


def icon_square(size=64, rgb=(235, 228, 210), filled=True):
    from PIL import ImageDraw
    im = icon_canvas(size)
    d = ImageDraw.Draw(im)
    c = tuple(rgb) + (255,)
    box = [size * 0.16, size * 0.16, size * 0.84, size * 0.84]
    if filled:
        d.rectangle(box, fill=c)
    else:
        d.rectangle(box, outline=c, width=max(2, size // 14))
    return im


def icon_dots(size=64, rgb=(235, 228, 210), cols=4, rows=3):
    """A block of dots - formation shapes read as arrangements of men."""
    from PIL import ImageDraw
    im = icon_canvas(size)
    d = ImageDraw.Draw(im)
    c = tuple(rgb) + (255,)
    r = max(2, size // 18)
    for iy in range(rows):
        for ix in range(cols):
            x = size * (0.18 + 0.64 * (ix / max(1, cols - 1)))
            y = size * (0.22 + 0.56 * (iy / max(1, rows - 1)))
            d.ellipse([x - r, y - r, x + r, y + r], fill=c)
    return im


# ---------------------------------------------------------------- atlas

def build_atlas(swf_path, xml_path, element, items, stage_w=1280, stage_h=720):
    """items: list of dicts, each becoming one named MovieClip.

    {"kind":"rect",  "name":..., "w":px, "h":px, "rgb":(r,g,b)}
    {"kind":"image", "name":..., "img":PIL.Image}
    {"kind":"text",  "name":..., "text":str, "px":int, "rgb":(r,g,b), "bold":bool}
    """
    tags = bytearray()
    tags += M.tag(69, struct.pack("<I", 0))          # FileAttributes, required for SWF 8
    tags += M.tag(9, bytes((10, 10, 12)))

    names, meta = [], {}
    cid, depth = 1, 1
    for it in items:
        kind, name = it["kind"], it["name"]
        if kind == "rect":
            shape_id = cid; cid += 1
            tags += M.define_shape_rect(shape_id, it["w"], it["h"], it.get("rgb", (255, 255, 255)))
            meta[name] = (it["w"], it["h"])
        else:
            if kind == "text":
                img = render_text(it["text"], it.get("px", 28), it.get("rgb", (235, 228, 210)),
                                  bold=it.get("bold", False))
            else:
                img = it["img"]
            bmp_id = cid; cid += 1
            shape_id = cid; cid += 1
            bits, iw, ih = M.define_bits_lossless2(bmp_id, img)
            tags += bits
            tags += M.define_shape_bitmap(shape_id, bmp_id, iw, ih)
            meta[name] = (iw, ih)
        sprite_id = cid; cid += 1
        tags += M.define_sprite(sprite_id, shape_id)
        tags += M.place(sprite_id, depth, name, 0, 0)
        depth += 1
        names.append(name)

    tags += M.do_action_stop()                        # a looping frame would reset every clip
    tags += M.tag(1, b"")
    tags += M.tag(0, b"")

    header = M.rect(0, stage_w * M.TWIP, 0, stage_h * M.TWIP)
    header += struct.pack("<H", 24 << 8) + struct.pack("<H", 1)
    body = header + bytes(tags)
    swf = b"FWS" + bytes([8]) + struct.pack("<I", 8 + len(body)) + body

    os.makedirs(os.path.dirname(swf_path), exist_ok=True)
    with open(swf_path, "wb") as f:
        f.write(swf)
    M.write_xml(xml_path, element, element, names)
    return swf, names, meta


def write_metrics(path, meta, stage_w=1280, stage_h=720):
    """Emit the clip sizes as a Lua table.

    Lua has no way to ask how big a clip is, and every layout decision needs that - a label
    cannot be centred without its width. Generating it here keeps the art and the layout code
    from drifting apart.
    """
    keys = sorted(meta)
    lines = ["-- GENERATED by tools/make_ui.py - do not edit by hand.",
             "-- Natural pixel size of every clip in the atlas, at 100% scale.",
             "mercenaries.UIAtlas = {",
             "    stageW = %d, stageH = %d," % (stage_w, stage_h),
             "    size = {"]
    for k in keys:
        w, h = meta[k]
        lines.append('        ["%s"] = { w = %d, h = %d },' % (k, w, h))
    lines += ["    },", "}", ""]
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="ascii") as f:
        f.write("\n".join(lines))
    return len(keys)


if __name__ == "__main__":
    items = [
        {"kind": "rect", "name": "panel", "w": 400, "h": 120, "rgb": (16, 16, 20)},
        {"kind": "image", "name": "ico_inf", "img": icon_infantry()},
        {"kind": "image", "name": "ico_arc", "img": icon_archer()},
        {"kind": "image", "name": "ico_cav", "img": icon_cavalry()},
        {"kind": "text", "name": "lbl_demo", "text": "Shield Wall", "px": 30, "bold": True},
    ]
    swf, names, meta = build_atlas("data/libs/UI/MercDemo.swf",
                                   "data/libs/UI/UIElements/MercDemo.xml",
                                   "MercDemo", items)
    print("wrote MercDemo.swf  %d bytes, %d clips" % (len(swf), len(names)))
    for n in names:
        print("   %-10s %dx%d" % (n, meta[n][0], meta[n][1]))
