"""Raster primitives every screen ends up needing.

Everything is drawn supersampled and downsampled once at the end, because a SWF bitmap has
no antialiasing of its own and a 1px rim drawn straight looks like a staircase in game.

All sizes here are in AUTHORED PIXELS, i.e. stage units times the atlas's `ss`. Use
`Atlas.px()` or multiply yourself; mixing the two is the easiest way to end up with a panel
that is a third of the size you meant.
"""
from PIL import Image, ImageDraw, ImageFilter

from . import fonts

AA = 4          # extra supersampling inside a single primitive


def _canvas(w, h, k=AA):
    im = Image.new("RGBA", (int(w * k), int(h * k)), (0, 0, 0, 0))
    return im, ImageDraw.Draw(im)


def _done(im, w, h):
    return im.resize((max(1, int(w)), max(1, int(h))), Image.LANCZOS)


def solid(w, h, rgb, alpha=1.0):
    """A flat rectangle. For a plain panel with no rounding, Atlas.solid() is cheaper -
    this one exists for when you want to composite something on top of it."""
    return Image.new("RGBA", (max(1, int(w)), max(1, int(h))),
                     tuple(rgb) + (int(255 * alpha),))


def disc(d, rgb, alpha=1.0, ring=None, ring_w=0.0):
    """A filled circle, optionally with a rim. The button shape for a radial menu."""
    im, g = _canvas(d, d)
    k = AA
    g.ellipse([0, 0, d * k - 1, d * k - 1], fill=tuple(rgb) + (int(255 * alpha),))
    if ring and ring_w > 0:
        rw = max(1, int(ring_w * k))
        g.ellipse([rw // 2, rw // 2, d * k - 1 - rw // 2, d * k - 1 - rw // 2],
                  outline=tuple(ring) + (255,), width=rw)
    return _done(im, d, d)


def rounded(w, h, r, rgb, alpha=1.0, edge=None, edge_w=0.0):
    """A rounded rectangle. The panel shape - a hard-cornered box reads as a debug overlay."""
    im, g = _canvas(w, h)
    k = AA
    g.rounded_rectangle([0, 0, w * k - 1, h * k - 1], radius=max(1, int(r * k)),
                        fill=tuple(rgb) + (int(255 * alpha),))
    if edge and edge_w > 0:
        ew = max(1, int(edge_w * k))
        g.rounded_rectangle([ew // 2, ew // 2, w * k - 1 - ew // 2, h * k - 1 - ew // 2],
                            radius=max(1, int(r * k)), outline=tuple(edge) + (255,),
                            width=ew)
    return _done(im, w, h)


def bar(w, h, frac, bg, fg, alpha=1.0):
    """A progress/health bar baked at one fill level. For a bar that MOVES, make it one
    clip and scale it from Lua instead - baking a clip per level is how an atlas gets to
    seven thousand clips."""
    im = solid(w, h, bg, alpha)
    if frac > 0:
        im.paste(solid(max(1, int(w * min(1.0, frac))), h, fg, alpha), (0, 0))
    return im


def vignette(n, k=256, strength=1.0):
    """A soft dark blob to sit a radial menu on.

    The falloff is computed rather than taken from Image.radial_gradient, which normalises
    to the image corners and so leaves a visible square edge.
    """
    a = Image.new("L", (k, k), 0)
    px = a.load()
    c = (k - 1) / 2.0
    for y in range(k):
        for x in range(k):
            d = (((x - c) ** 2 + (y - c) ** 2) ** 0.5) / c
            v = max(0.0, 1.0 - d) ** 2.2
            px[x, y] = int(255 * v * strength)
    im = Image.new("RGBA", (k, k), (0, 0, 0, 0))
    im.putalpha(a)
    return im.resize((int(n), int(n)), Image.LANCZOS)


def _halo(ink, px, pad, shadow):
    """Pad a rasterised run and give it the dark halo that keeps it legible over bright
    terrain. Padding is a CONSTANT, not a fraction of the size: padding by `px // 4` put a
    9px label and a 19px title on rails 2.7 units apart and nothing in a column lined up."""
    p = int(pad if pad is not None else max(2, px // 6))
    im = Image.new("RGBA", (ink.size[0] + p * 2, ink.size[1] + p * 2), (0, 0, 0, 0))
    if shadow:
        sh = Image.new("RGBA", im.size, (0, 0, 0, 0))
        sh.paste(Image.new("RGBA", ink.size, (0, 0, 0, 210)), (p, p), ink)
        sh = sh.filter(ImageFilter.GaussianBlur(max(1, px / 9.0)))
        im = Image.alpha_composite(im, sh)
        im = Image.alpha_composite(im, sh)
    top = Image.new("RGBA", im.size, (0, 0, 0, 0))
    top.paste(ink, (p, p), ink)
    return Image.alpha_composite(im, top)


def text(s, px, rgb, face="bold", shadow=True, tracking=0.0, pad=None, crop=True):
    """A label in the game's own typeface.

    `crop=True` trims to the ink, which is right for a standalone label. It is WRONG for a
    set of glyphs that have to line up with each other - use `glyph_set` for those.
    """
    ink = fonts.text(s, px, rgb, face=face, tracking=tracking * px)
    if crop:
        bb = ink.split()[3].getbbox()
        if bb is None:
            return ink
        ink = ink.crop(bb)
    return _halo(ink, px, pad, shadow)


def glyph_set(chars, px, rgb, face="bold", shadow=False, pad=None):
    """One image per character, all sharing a baseline. Returns {char: image}.

    Cropping each glyph to its own ink and then centring them all - the obvious thing to do
    - silently destroys the baseline: a full-height "6" and a period both end up centred on
    the same line, so "6.5" prints as "6·5" with the dot floating at mid height. The font
    renderer already returns a consistent ascent+descent box, so the fix is to trim the
    dead space ONCE for the whole set vertically, and per-glyph only horizontally.

    Horizontal cropping still matters: advancing by an uncropped clip width puts six units
    of air between every digit. For the same reason the default padding here is ZERO when
    there is no halo to make room for - figures sit on a dark panel and are set solid, so
    they rarely need one.
    """
    if pad is None:
        pad = max(2, px // 6) if shadow else 0
    raw = {}
    for ch in chars:
        raw[ch] = fonts.text(ch, px, rgb, face=face)

    tops, bots = [], []
    for im in raw.values():
        bb = im.split()[3].getbbox()
        if bb:
            tops.append(bb[1])
            bots.append(bb[3])
    y0 = min(tops) if tops else 0
    y1 = max(bots) if bots else 1

    out = {}
    for ch, im in raw.items():
        bb = im.split()[3].getbbox()
        if bb is None:                              # a space: keep the advance, no ink
            x0, x1 = 0, max(1, im.size[0] - 2)
        else:
            x0, x1 = bb[0], max(bb[2], bb[0] + 1)
        out[ch] = _halo(im.crop((x0, y0, x1, max(y1, y0 + 1))), px, pad, shadow)
    return out


def load(path, box=None, tint=None):
    """An icon off disk, optionally recoloured to a flat tint through its own alpha.

    Tinting is what lets one drawn glyph serve as the live, dimmed and disabled versions of
    an icon without three source files.
    """
    im = Image.open(path).convert("RGBA")
    if box:
        w, h = im.size
        k = min(box / float(w), box / float(h))
        im = im.resize((max(1, int(w * k)), max(1, int(h * k))), Image.LANCZOS)
    if tint:
        flat = Image.new("RGBA", im.size, tuple(tint) + (255,))
        flat.putalpha(im.split()[3])
        im = flat
    return im
