"""A screen described as data, compiled to the three artefacts plus an offline preview.

The point of the data file is not that JSON is nicer than Python. It is that a screen
described as data can be **rendered without the game**, so the tuning loop is a second long
instead of a two-minute alt-tab, and a layout number can be checked by eye before anyone
launches anything.

Every size in a scene is in STAGE UNITS on the declared stage (1280x720 by default).
Supersampling is the compiler's business, not the author's.

    {
      "element": "MercDemo",
      "table":   "MercDemoAtlas",
      "out":     { "swf": "...", "xml": "...", "lua": "..." },
      "palette": { "ink": [238, 231, 216], "panel": [26, 21, 15] },
      "layout":  { "panelX": 40, "panelY": 40 },
      "clips":   [ { "name": "panel", "kind": "rounded", "w": 300, "h": 120, ... } ],
      "preview": [ { "clip": "panel", "x": 40, "y": 40 } ]
    }
"""
import json
import os

from . import art
from .atlas import Atlas


class SceneError(Exception):
    pass


def _rgb(v, palette, default=(255, 255, 255)):
    if v is None:
        return default
    if isinstance(v, str):
        if v not in palette:
            raise SceneError("unknown palette colour %r" % v)
        return tuple(palette[v])
    return tuple(v)


def load(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def _image(c, U, palette, root, where):
    """One clip spec -> one PIL image. Shared by plain clips and by the frames of a
    multi-state clip, so a state is described exactly like a clip."""
    kind = c.get("kind", "image")
    if kind == "rounded":
        return art.rounded(U(c["w"]), U(c["h"]), U(c.get("r", 6)),
                           _rgb(c.get("rgb"), palette), c.get("alpha", 1.0),
                           _rgb(c["edge"], palette) if c.get("edge") else None,
                           U(c["edgeW"]) if c.get("edgeW") else 0)
    if kind == "disc":
        return art.disc(U(c["d"]), _rgb(c.get("rgb"), palette), c.get("alpha", 1.0),
                        _rgb(c["ring"], palette) if c.get("ring") else None,
                        U(c["ringW"]) if c.get("ringW") else 0)
    if kind == "rect":
        return art.solid(U(c["w"]), U(c["h"]), _rgb(c.get("rgb"), palette),
                         c.get("alpha", 1.0))
    if kind == "bar":
        return art.bar(U(c["w"]), U(c["h"]), float(c.get("frac", 1.0)),
                       _rgb(c.get("bg"), palette, (40, 38, 34)),
                       _rgb(c.get("fg"), palette), c.get("alpha", 1.0))
    if kind == "vignette":
        return art.vignette(U(c["d"]), strength=c.get("strength", 1.0))
    if kind == "text":
        return art.text(c["text"], U(c.get("px", 12)), _rgb(c.get("rgb"), palette),
                        face=c.get("face", "bold"), shadow=c.get("shadow", True),
                        tracking=c.get("tracking", 0.0))
    if kind == "image":
        return art.load(os.path.join(root, c["file"]),
                        box=U(c["box"]) if c.get("box") else None,
                        tint=_rgb(c["tint"], palette) if c.get("tint") else None)
    raise SceneError("%s: unknown kind %r" % (where, kind))


def compile(scene, root=".", strict_preview=True):
    """Build the Atlas a scene describes. Does not write anything."""
    palette = {k: tuple(v) for k, v in (scene.get("palette") or {}).items()}
    stage = tuple(scene.get("stage", (1280, 720)))
    ss = int(scene.get("ss", 3))
    A = Atlas(scene["element"], stage=stage, ss=ss)

    def U(v):
        """Stage units -> authored pixels."""
        return max(1, int(round(float(v) * ss)))

    for i, c in enumerate(scene.get("clips") or []):
        where = "clips[%d]" % i

        if "digits" in c:
            images = art.glyph_set(c.get("glyphs", "0123456789"),
                                   U(c.get("px", 14)), _rgb(c.get("rgb"), palette),
                                   face=c.get("face", "bold"),
                                   shadow=bool(c.get("shadow", False)))
            A.digits(c["digits"], int(c.get("width", 6)), images)
            continue

        name = c.get("name")
        if not name:
            raise SceneError("%s has no name" % where)
        center = bool(c.get("center", True))

        if c.get("kind") == "states":
            frames = []
            for j, f in enumerate(c["frames"]):
                label = f["label"]
                key = f.get("key", "%s_%s" % (name, label))
                if key not in A.shapes:
                    A.image(key, _image(f, U, palette, root,
                                        "%s.frames[%d]" % (where, j)))
                frames.append((label, key))
            A.states(name, frames, center=center, loop=bool(c.get("loop", False)))
            continue

        key = c.get("key", name + "_art")
        img = None if key in A.shapes else _image(c, U, palette, root, where)
        A.clip(name, key, img, center=center)

    # The preview is also a contract check: a clip named in it that does not exist is a
    # typo that would have shown up in game as nothing drawing.
    if strict_preview:
        for p in scene.get("preview") or []:
            if p["clip"] not in A.meta:
                raise SceneError("preview references a clip that does not exist: %s"
                                 % p["clip"])
    return A


def write(scene, A, root="."):
    out = scene.get("out") or {}
    written = {}
    if "swf" in out:
        data = A.write_swf(os.path.join(root, out["swf"]))
        written["swf"] = (os.path.join(root, out["swf"]), len(data))
    if "xml" in out:
        A.write_xml(os.path.join(root, out["xml"]))
        written["xml"] = (os.path.join(root, out["xml"]), len(A.names))
    if "lua" in out:
        n = A.write_lua(os.path.join(root, out["lua"]),
                        scene.get("table", A.element + "Atlas"),
                        layout=scene.get("layout"),
                        generator="tools/kcdui on " + os.path.basename(
                            scene.get("_source", "a scene file")),
                        **(scene.get("extra") or {}))
        written["lua"] = (os.path.join(root, out["lua"]), n)
    return written


def preview(scene, A, path, scale=1.5, sky=True):
    """Compose the screen exactly as the runtime will lay it out.

    It uses the same art and the same coordinates, and it reads the `c` anchor flag the
    same way the Lua does, so a clip that will sit half its own size out of place sits half
    its own size out of place here too.
    """
    from PIL import Image, ImageDraw
    W, H = int(A.stage_w * scale), int(A.stage_h * scale)
    bg = Image.new("RGBA", (W, H), (0, 0, 0, 255))
    if sky:
        # A sky-and-ground gradient, because a UI that looks fine on black can be
        # unreadable over bright terrain - which is what the halo on text is for.
        g = ImageDraw.Draw(bg)
        for y in range(H):
            t = y / float(H)
            if t < 0.62:
                u = t / 0.62
                g.line([(0, y), (W, y)],
                       fill=(int(96 + 70 * u), int(126 + 66 * u), int(168 + 52 * u)))
            else:
                u = (t - 0.62) / 0.38
                g.line([(0, y), (W, y)],
                       fill=(int(96 - 40 * u), int(92 - 36 * u), int(74 - 30 * u)))

    for p in scene.get("preview") or []:
        name = p["clip"]
        meta = A.meta[name]
        im = A.art.get(p.get("key") or A.keyof.get(name))
        if im is None:
            continue                                # a solid() clip has no bitmap
        m = float(p.get("scale", 1.0))
        w = max(1, int(im.size[0] * scale / A.ss * m))
        h = max(1, int(im.size[1] * scale / A.ss * m))
        im = im.resize((w, h), Image.LANCZOS)
        if p.get("alpha", 1.0) < 1.0:
            a = im.getchannel("A").point(lambda v: int(v * p["alpha"]))
            im = im.copy()
            im.putalpha(a)
        x, y = float(p["x"]), float(p["y"])
        if meta.get("c", True):
            px, py = int(x * scale - w / 2), int(y * scale - h / 2)
        else:
            px, py = int(x * scale), int(y * scale)
        bg.alpha_composite(im, (px, py))

    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    bg.convert("RGB").save(path)
    return path


def build(path, root=None, preview_path=None, scale=1.5):
    """Compile, write and optionally preview one scene file."""
    scene = load(path)
    scene["_source"] = os.path.basename(path)
    root = root if root is not None else os.path.dirname(os.path.abspath(path))
    A = compile(scene, root=root)
    written = write(scene, A, root=root)
    if preview_path:
        preview(scene, A, preview_path, scale=scale)
    return A, written
