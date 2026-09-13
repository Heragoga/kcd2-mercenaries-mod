"""The game's own typefaces, read straight out of its paks.

A mod UI set in Segoe or Georgia reads as a mod however good the layout is; set in the
game's own faces it reads as part of the game. KCD2's outlines are extractable, but only
from **`Libs/UI/gfxfontlib_glyphs.gfx`** - the obvious-looking `gfxfontlib.gfx` has the
outlines stripped out of it, which is a good hour lost if you find that one first.

This wraps `tools/kcd_font.py`, which does the real work (CFX container -> DefineFont3 ->
SHAPE records -> a filled polygon). Kept behind a wrapper so a screen builder can fall back
to a system font when the game is not installed on the build machine, rather than failing.
"""
import os
import sys

_TOOLS = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if _TOOLS not in sys.path:
    sys.path.insert(0, _TOOLS)

FACES = ("body", "bold", "display", "light")

_backend = None
_warned = False


def _load():
    global _backend
    if _backend is None:
        try:
            import kcd_font
            _backend = kcd_font
        except Exception:
            _backend = False
    return _backend


def available():
    """True if the game's fonts can be read on this machine."""
    be = _load()
    if not be:
        return False
    try:
        be.face("body")
        return True
    except Exception:
        return False


def _fallback(s, px, rgb, tracking=0.0):
    global _warned
    from PIL import Image, ImageDraw, ImageFont
    if not _warned:
        sys.stderr.write("kcdui: the game's fonts are not readable here - falling back to "
                         "a system font. Text metrics will NOT match the shipped build.\n")
        _warned = True
    for cand in ("segoeui.ttf", "georgia.ttf", "DejaVuSans.ttf"):
        try:
            f = ImageFont.truetype(cand, max(1, int(px)))
            break
        except Exception:
            f = None
    if f is None:
        f = ImageFont.load_default()
    probe = ImageDraw.Draw(Image.new("RGBA", (8, 8)))
    l, t, r, b = probe.textbbox((0, 0), s, font=f)
    im = Image.new("RGBA", (max(1, r - l + 4), max(1, b - t + 4)), (0, 0, 0, 0))
    ImageDraw.Draw(im).text((2 - l, 2 - t), s, font=f, fill=tuple(rgb) + (255,))
    return im


def text(s, px, rgb, face="bold", tracking=0.0):
    """Rasterise a string in one of the game's faces. `px` is a cap height."""
    be = _load()
    if be:
        try:
            return be.text(s, px, rgb, font=face, tracking=tracking)
        except Exception:
            pass
    return _fallback(s, px, rgb, tracking)


def measure(s, px, face="bold", tracking=0.0):
    be = _load()
    if be:
        try:
            return be.measure(s, px, font=face, tracking=tracking)
        except Exception:
            pass
    return _fallback(s, px, (255, 255, 255), tracking).size
