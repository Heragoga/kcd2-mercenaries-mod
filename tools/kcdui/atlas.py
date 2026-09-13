"""The atlas: the contract that stops the art and the Lua drifting apart.

Three artefacts come out of one build, and all three have to agree on every clip name:

    Libs/UI/<Element>.swf              the art, one MovieClip per thing that can move
    Libs/UI/UIElements/<Element>.xml   declares those clips to the engine
    Scripts/mods/<name>atlas.lua       clip sizes and layout constants, for the driver

The driver never hard-codes a size, a position or a list of items - it reads them from the
table emitted here. That is the only thing that makes a rebuild safe.
"""
import os

from . import swf as S

PARK = -3000        # clips start off-stage so nothing flashes before Lua lays them out


def lua_value(v, indent=0):
    """Serialise Python data as a Lua literal. Tables keep insertion order for lists and
    sort for dicts, so a rebuild produces a stable diff."""
    pad = "    " * indent
    if isinstance(v, bool):
        return "true" if v else "false"
    if v is None:
        return "nil"
    if isinstance(v, (int,)):
        return str(v)
    if isinstance(v, float):
        return ("%.4f" % v).rstrip("0").rstrip(".") or "0"
    if isinstance(v, str):
        return '"' + v.replace("\\", "\\\\").replace('"', '\\"') + '"'
    if isinstance(v, (list, tuple)):
        inner = ", ".join(lua_value(x, indent) for x in v)
        return "{ %s }" % inner
    if isinstance(v, dict):
        if not v:
            return "{}"
        rows = []
        for k in sorted(v, key=str):
            key = k if isinstance(k, str) and k.isidentifier() else "[%s]" % lua_value(k)
            rows.append("%s    %s = %s," % (pad, key, lua_value(v[k], indent + 1)))
        return "{\n" + "\n".join(rows) + "\n" + pad + "}"
    raise TypeError("cannot write %r as Lua" % (v,))


class Atlas:
    """Every visual is a bitmap (or a solid rect) wrapped in a named MovieClip.

    Sprites share shapes and shapes share bitmaps, so a screen needing 900 clips costs
    about 200 unique images.

    Two names, and confusing them is the classic first mistake:

      * **name** is the INSTANCE - what UIAction.SetPos can move, and what the driver
        addresses. Two places showing the same picture are two instances.
      * **key** is the IMAGE, shared freely between instances.

    Art is authored at `ss` times stage size and the clip's own matrix bakes in the 1/ss
    shrink, so text and curves are supersampled. Any SetScale from Lua must re-apply that
    shrink or the clip jumps to ss times its intended size - the runtime's `place` does.
    """

    def __init__(self, element, stage=(1280, 720), ss=3):
        self.element = element
        self.stage_w, self.stage_h = stage
        self.ss = ss
        self.tags = bytearray(S.header_tags())
        self.cid, self.depth = 1, 1
        self.shapes = {}        # key -> (shape_id, w_px, h_px)
        self.art = {}           # key -> PIL image, for the offline preview
        self.names = []         # instance names, in placement order
        self.meta = {}          # instance -> dict for the Lua table
        self.keyof = {}         # instance -> image key, for the offline preview only

    # -------------------------------------------------------------- images
    def image(self, key, img=None):
        """Register a shared image once. Returns (shape_id, w, h) in authored pixels."""
        if key in self.shapes:
            return self.shapes[key]
        if img is None:
            raise KeyError("no art registered for %r - pass img= the first time" % (key,))
        bid = self.cid; self.cid += 1
        bits, w, h = S.define_bits_lossless2(bid, img)
        self.tags += bits
        sid = self.cid; self.cid += 1
        self.tags += S.define_shape_bitmap(sid, bid, w, h)
        self.shapes[key] = (sid, w, h)
        self.art[key] = img
        return self.shapes[key]

    def solid(self, key, w, h, rgb):
        """A solid rectangle as a shape, with no bitmap behind it. Cheaper than an image
        for a plain panel, but it cannot have rounded corners or an alpha gradient."""
        if key in self.shapes:
            return self.shapes[key]
        sid = self.cid; self.cid += 1
        wp, hp = int(w * self.ss), int(h * self.ss)
        self.tags += S.define_shape_solid(sid, wp, hp, rgb)
        self.shapes[key] = (sid, wp, hp)
        return self.shapes[key]

    # -------------------------------------------------------------- clips
    def clip(self, name, key, img=None, center=True, **extra):
        """One movable instance.

        `center=True` registers the clip at its middle, `False` at its top-left corner.
        The flag is emitted into the Lua as `c` and the runtime converts, so a driver can
        always say where the MIDDLE goes. Skip that and every uncentred clip sits half its
        own size down and to the right - which looks like a layout bug and is not one.
        """
        sid, w, h = self.image(key, img)
        return self._place(name, [(sid, None)], w, h, center, key, **extra)

    def states(self, name, frames, center=True, loop=False, **extra):
        """One instance whose look Lua can swap with GotoAndStopFrameName.

        `frames` is a list of (label, key) - the image must already be registered, or pass
        (label, key, img). Use it where a thing has states rather than positions: a button
        that is normal/hover/disabled is ONE clip with three frames, not three clips you
        have to remember to hide.

        With loop=True the clip animates on its own once GotoAndPlay starts it. Only reach
        for that when the motion is decorative; anything the player reads should be driven
        from Lua so it cannot drift out of step with the state it is showing.
        """
        built, w, h = [], 0, 0
        for f in frames:
            label, key = f[0], f[1]
            img = f[2] if len(f) > 2 else None
            sid, fw, fh = self.image(key, img)
            w, h = max(w, fw), max(h, fh)
            built.append((sid, label))
        return self._place(name, built, w, h, center, frames[0][1], loop=loop, **extra)

    def _place(self, name, frames, w, h, center, key, loop=False, **extra):
        if name in self.meta:
            raise ValueError("duplicate instance name %r - an instance can only be in one "
                             "place at a time, so two of them means two names" % (name,))
        if not name.isascii():
            raise ValueError("instance name %r must be ASCII" % (name,))
        spid = self.cid; self.cid += 1
        ox, oy = (-(w // 2) * S.TWIP, -(h // 2) * S.TWIP) if center else (0, 0)
        self.tags += S.define_sprite(spid, frames, ox, oy, loop)
        self.tags += S.place(spid, self.depth, name, 1.0 / self.ss, 1.0 / self.ss,
                             PARK * S.TWIP, PARK * S.TWIP)
        self.depth += 1
        self.names.append(name)
        row = {"w": round(w / float(self.ss), 2), "h": round(h / float(self.ss), 2)}
        if not center:
            row["c"] = False
        row.update(extra)
        self.meta[name] = row
        self.keyof[name] = key
        return name

    # -------------------------------------------------------------- numbers
    # Characters that cannot appear in a clip name, mapped to a word. The runtime's
    # KCDUI.GLYPH table is the other half of this and the two must agree.
    GLYPH_NAME = {"/": "slash", "%": "pct", "+": "plus", "-": "minus", ",": "comma",
                  ".": "dot", ":": "colon", " ": "space"}

    def digits(self, field, width, images):
        """One instance per character POSITION, which is the only way numbers work.

        An instance can only be in one place at a time, so a figure built from a shared set
        of ten digit clips asks the single "0" instance to be in two places when it draws
        500. Every figure that can be on screen beside another one needs its own column:

            n_<field>_<pos>_<glyph>

        `images` is {char: image}, and must carry every separator the field can ever print
        - "/", "%", "+", a space. A character with no clip is silently skipped, which is
        how "2 / 6" once rendered as "2 6". Build it with art.glyph_set so the glyphs share
        a baseline.
        """
        made = []
        for pos in range(1, width + 1):
            for ch, img in images.items():
                g = self.GLYPH_NAME.get(ch, ch)
                key = "g_%s_%s" % (field, g)
                made.append(self.clip("n_%s_%d_%s" % (field, pos, g), key,
                                      img if key not in self.shapes else None,
                                      center=False))
        return made

    # -------------------------------------------------------------- output
    def swf_bytes(self):
        return S.movie(self.tags, self.stage_w, self.stage_h)

    def write_swf(self, path):
        os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
        data = self.swf_bytes()
        with open(path, "wb") as f:
            f.write(data)
        return data

    def write_xml(self, path, layer=36):
        """The UIElements contract.

        The declared movie is `<element>.gfx`: with wh_gfx_useSWF set, the loader strips
        "gfx" and appends "swf", so the .gfx name is what must appear here even though a
        .swf is what ships.
        """
        clips = "\n".join('      <MovieClip name="%s" instancename="%s" />' % (n, n)
                          for n in self.names)
        xml = ('<UIElements name="{e}">\n\n'
               '  <UIElement name="{e}" layer="{l}" mouseevents="0" keyevents="0" cursor="0">\n\n'
               '    <GFx file="{e}.gfx" layer="{l}">\n'
               '      <Constraints>\n'
               '        <Align mode="fullscreen" />\n'
               '      </Constraints>\n'
               '    </GFx>\n\n'
               '    <functions>\n'
               '    </functions>\n\n'
               '    <events>\n'
               '    </events>\n\n'
               '    <arrays>\n'
               '    </arrays>\n\n'
               '    <movieclips>\n{c}\n    </movieclips>\n\n'
               '  </UIElement>\n\n'
               '</UIElements>\n').format(e=self.element, l=layer, c=clips)
        os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
        with open(path, "w", encoding="ascii") as f:
            f.write(xml)
        return xml

    def write_lua(self, path, table_name, layout=None, generator="kcdui", **extra):
        """The table the driver reads. Everything the layout code needs lives here, so the
        two cannot disagree about a size, a position or a list of items."""
        body = {
            "element": self.element,
            "stageW": self.stage_w, "stageH": self.stage_h,
            "ss": self.ss,
            "layout": layout or {},
        }
        body.update(extra)

        lines = ["-- GENERATED by %s - do not edit by hand." % generator,
                 "-- Clip sizes and layout geometry for the %s screen." % self.element,
                 "",
                 "%s = %s" % (table_name, lua_value(body)[:-1].rstrip() or "{")]
        # The size table is written by hand rather than through lua_value: every key is
        # bracketed and quoted whether or not it happens to be a valid Lua identifier, so
        # a clip name starting with a digit, or a tool grepping for the rows, both work.
        lines.append("    size = {")
        for n in sorted(self.meta):
            row = self.meta[n]
            parts = ["w = %s" % lua_value(row["w"]), "h = %s" % lua_value(row["h"])]
            for k in sorted(row):
                if k not in ("w", "h"):
                    parts.append("%s = %s" % (k, lua_value(row[k])))
            lines.append('        ["%s"] = { %s },' % (n, ", ".join(parts)))
        lines += ["    },", "}", ""]

        os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
        with open(path, "w", encoding="ascii") as f:
            f.write("\n".join(lines))
        return len(self.meta)
