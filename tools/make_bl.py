"""Build the Bannerlord-style command UI: MercBL.swf, its UIElements XML and the Lua
layout table that drives it.

Geometry and palette are measured off Alex's own Bannerlord screenshots in
references/bannerlord ui - see docs/command-ui.md. Glyphs come from the mod's own icon
set in assets/ui/command-icons-v1.

Everything the Lua driver needs is emitted into data/Scripts/mods/mercenaries_blatlas.lua,
so the art and the layout code cannot drift apart.

    python tools/make_bl.py              build the atlas, the XML and the Lua table
    python tools/make_bl.py --preview    also render tools/out/blui_preview.png
"""
import os, sys, struct, math

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_swf as M

from PIL import Image, ImageDraw, ImageFont, ImageOps, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ICONS = os.path.join(ROOT, "assets", "ui", "command-icons-v2")
ICONS_ALT = os.path.join(ROOT, "assets", "ui", "outfit-icons-v1")

# The SWF stage. Scaleform scales the whole movie to the viewport, so these are the only
# coordinates anything is written in. SS supersamples every bitmap so a 4K screen - which
# is exactly 3x this stage - gets 1:1 pixels instead of an upscale.
STAGE_W, STAGE_H = 1280, 720
SS = 3

GLYPH_ALPHA_FLOOR = 12      # below this, a pixel is halo rather than ink

import kcd_font

# Kingdom Come Regular sets a taller cap than Segoe did at the same nominal size;
# every px in this file is a Segoe-equivalent cap height, scaled through this.
KCD_CAP = 1.0

# ---------------------------------------------------------------- palette (measured)

GLYPH        = (243, 239, 229)
LABEL        = (238, 231, 216)
DISC_PLAIN   = (34, 32, 29)
DISC_PLAIN_A = 0.93
DISC_RIM     = (120, 92, 45)
DISC_ON      = (10, 10, 12)
DISC_ON_A    = 0.92
RING_GOLD    = (214, 168, 78)
CHIP_BG      = (28, 26, 22)
CHIP_TEXT    = (232, 226, 208)
# The corner prompt uses KCD2's OWN key-cap art, not an imitation of it - see keycap().
HINT_BTN_TEXT = (0, 0, 0)           # DefineEditText id=103 in Libs/UI/buttons.gfx
CARD_FILL    = (26, 21, 15)
CARD_FILL_A  = 0.78
CARD_FILL_SEL   = (49, 27, 7)
CARD_FILL_SEL_A = 0.88
CARD_EDGE     = (150, 112, 52)
CARD_EDGE_SEL = (226, 170, 74)
HP_BG        = (14, 13, 12)
HP_GOOD      = (112, 150, 82)
HP_WARN      = (214, 166, 62)
HP_BAD       = (178, 66, 46)
HP_DEAD      = (92, 26, 22)   # men lost since the fight started

# ---------------------------------------------------------------- layout (stage units)

L = dict(
    # Bottom button row. Raised well off the very bottom: KCD2 puts the health and stamina
    # vignette bottom-centre, which is exactly where Bannerlord puts this row.
    rowY=566, btnPitch=74, btnD=55,
    btnBadgeDY=-32, btnLabelDY=38, btnOpenScale=1.18,
    # Radial submenu, centred above whichever button owns it. Its discs are noticeably
    # smaller than the row's, and badge and label sit right on the disc rim.
    wheelDY=-166, wheelR=86, wheelD=41,
    wheelBadgeDY=-21, wheelLabelDY=31, wheelSelScale=1.14,
    vig=400,
    # Squad cards down the left edge. Portrait, like Bannerlord's, but shortened so five
    # squads fit the column where Bannerlord only ever stacks four.
    cardX=18, cardW=72, cardH=104, cardY0=32, cardPitch=128,
    cardChipDX=84, cardIconDX=15, cardIconDY=15, cardCountDX=33, cardCountDY=15,
    cardWmDY=8, cardHpDY=-11, cardHpW=58, cardHpH=6,
    cardOrderDY=12,
    # Idle prompt: Command [H], laid out like KCD2's own action hint - label first, cap
    # second, the column anchored on its RIGHT EDGE so the caps line up whatever the words
    # do. Every anchor below is therefore a right edge. Which one is used is a player
    # setting (merc_hints_pos); hintEdge/hintY are the default, and what the preview draws.
    #
    # Bottom right was the original home and is where KCD2 puts its own pickup messages
    # AND its interaction prompts, which is exactly the complaint that moved it.
    hintEdge=1262, hintY=66, hintGap=7,
    hintRightX=1262, hintLeftX=200, hintTopY=32, hintBottomY=618,
    # Level with the compass and clear of its right end (the bar runs to about x=749).
    hintCompassX=865,
    # Row pitch. Wider than it was: the key caps are taller than the old badges, and
    # vanilla's own column is airier than a tight stack.
    hintRowDY=34,
)

KEY_POOL = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9",
            "H", "U", "O", "Y", "G", "K", "L", "N", "M", "ESC",
            "F2", "F3", "F4", "F6", "F7", "F8", "F9"]

# The default binding. The company fields at most four squads, so the number row splits
# cleanly: 1-4 pick squads (matching the index on each card) and 5-0 are the six order slots.
#
#     1 2 3 4   squads        5 6 7 8 9 0   orders        H  open / close / back
#
# 9 and 0 are bound only to the `haste` cheat map, so they are free outright. 5-8 are quick
# access menu slots (`qam_init`), which do not fire bare in the field - measured. H is one of
# the four letters KCD2 never binds, which matters because it is the only key held while the
# interface is hidden.
BIND = [("5", "5"), ("6", "6"), ("7", "7"), ("8", "8"), ("9", "9"), ("0", "0"),
        ("n", "N"), ("h", "H")]
HIDE_KEY = ("h", "H")
RETURN_SLOT = 8

TROOP_TYPES = ["infantry", "archer", "crossbow", "polearm", "handcannon", "mounted"]
TROOP_ICON = {
    "infantry": "troop_infantry", "archer": "troop_archer", "crossbow": "troop_crossbow",
    "polearm": "troop_polearm", "handcannon": "troop_handcannon", "mounted": "mounted",
}

# ---------------------------------------------------------------- the order tree
# (key, icon, label). Bannerlord's own wheels, trimmed to what this mod actually has.

MOVE = [
    ("move",     "move_to_position", "Move to Position"),
    ("follow",   "follow_me",        "Follow Me"),
    ("charge",   "charge",           "Charge"),
    ("stop",     "stop",             "Stop"),
    ("retreat",  "retreat",          "Retreat"),
    ("return",   "return",           "Return"),
]

# Matches mercenaries.FormationShapeOrder, reordered so Line leads like Bannerlord.
FORM = [
    ("line",   "formation_line",   "Line"),
    ("column", "formation_column", "Column"),
    ("square", "formation_square", "Square"),
    ("wedge",  "formation_wedge",  "Wedge"),
    ("circle", "formation_circle", "Circle"),
    ("escort", "formation_escort", "Escort"),
    ("return", "return",           "Return"),
]

# Weapon loadouts, indexing mercenaries.WeaponSets. Only six fit: a wheel can hold as many
# orders as there are order keys, and there are six. Archers get their own list because
# mercenaries.ArcherWeaponSets is a separate table - the Weapons button shows whichever list
# suits the selected squad.
WEAPONS_MELEE = [
    ("random",      "equipment_mixed",        "Random"),
    ("swordshield", "equipment_sword_shield", "Sword & Shield"),
    ("axeshield",   "equipment_axe_shield",   "Axe & Shield"),
    ("maceshield",  "equipment_mace_shield",  "Mace & Shield"),
    ("longsword",   "equipment_longsword",    "Longsword"),
    ("polearm",     "equipment_polearm",      "Polearm"),
    ("return",      "return",                 "Return"),
]

WEAPONS_RANGED = [
    ("bow",        "equipment_bow",        "Bow"),
    ("crossbow",   "equipment_crossbow",   "Crossbow"),
    ("handcannon", "equipment_handcannon", "Hand Cannon"),
    ("return",     "return",               "Return"),
]

# Stateful entries: the button shows whichever state is live.
TOGGLE = [
    ("fire",   [("on",  "fire_at_will", "Firing at will"),
                ("off", "hold_fire",    "Holding Fire")]),
    ("mount",  [("on",  "mounted",    "Mounted"),
                ("off", "dismounted", "Dismounted")]),
    # Engagement and swarm mirror mercenaries.EngageOrder / mercenaries.AggroOrder exactly -
    # same keys, same order - so the wheel cannot drift from the orders the mod can issue.
    ("engage", [("default",    "engagement_default",    "Engage at will"),
                ("aggressive", "engagement_aggressive", "Attack anyone"),
                ("defend",     "engagement_defend",     "Defend only"),
                ("hold",       "engagement_hold",       "Hold your blades")]),
    ("swarm",  [("tight",    "swarm_tight",    "Tight ranks"),
                ("balanced", "swarm_balanced", "Balanced"),
                ("loose",    "swarm_loose",    "Swarm them")]),
    ("return", [("return", "return", "Return")]),
]

# The wardrobe, indices matching docs/outfits.md. Seventeen styles will not fit a wheel that
# holds six, so the wheel pages five at a time and slot 6 steps to the next page. Every outfit
# slot therefore has to be able to wear any of the seventeen.
OUTFITS = [
    ("generic", "outfit_generic", "Generic Mercs"),
    ("bandits", "outfit_bandits", "Bandits"),
    ("cumans", "outfit_cumans", "Cumans"),
    ("leipa", "outfit_leipa", "Leipa"),
    ("kuttenberg", "outfit_kuttenberg", "Kuttenberg"),
    ("skalitz", "outfit_skalitz", "Skalitz"),
    ("custom", "outfit_custom", "Custom Uniform"),
    ("prague", "outfit_prague", "Prague"),
    ("sigismund", "outfit_sigismund", "Sigismund"),
    ("red_star", "outfit_red_star", "Red Star"),
    ("bergov", "outfit_bergov", "Bergov"),
    ("nebakov", "outfit_nebakov", "Nebakov"),
    ("semine", "outfit_semine", "Semine"),
    ("pisek", "outfit_pisek", "Pisek"),
    ("teutonic", "outfit_teutonic", "Teutonic Order"),
    ("ruthard", "outfit_ruthard", "Ruthard"),
    ("papal", "outfit_papal", "Papal Legate"),
]

OUTFIT_PAGE = 5
OUTFIT_WHEEL = ([("o%d" % i, [(k, ic, lb) for k, ic, lb in OUTFITS])
                 for i in range(1, OUTFIT_PAGE + 1)]
                + [("more", [("more", "settings_toggle", "More")]),
                   ("return", [("return", "return", "Return")])])

# The little glyph under each squad card. The movement icons plus a tent, because "in camp"
# is a state a squad can be in that no movement order describes.
CARD_STATES = [(k, ic) for k, ic, _lb in MOVE] + [("camp", "camp_tent")]

# Wheels whose entries are fixed, keyed by the category name the driver asks for.
SIMPLE_WHEELS = {"move": MOVE, "form": FORM,
                 "wpnm": WEAPONS_MELEE, "wpnr": WEAPONS_RANGED}
# Wheels whose every slot has its own set of states.
STATE_WHEELS = {"tog": TOGGLE, "outfit": OUTFIT_WHEEL}

# The always-visible bottom row. `src` says where the button's icon and label come from.
# Mount and Facing Direction lost their seats to Weapons and Squads - both still live in the
# Toggle wheel, which is where Bannerlord keeps its duplicates too.
BOTTOM = [
    ("move",    "move",   "Movement"),
    ("form",    "form",   "Formation"),
    ("toggle",  "fixed",  "Toggle"),
    ("weapons", "fixed",  "Weapons"),
    ("outfit",  "fixed",  "Clothing"),
    ("camp",    "fixed",  "Camp"),
]


# Buttons that simply open a wheel carry one fixed glyph of their own.
FIXED_BUTTON = {
    "toggle":  ("fixed", "settings_toggle",  "Toggle"),
    "weapons": ("fixed", "equipment_custom", "Weapons"),
    "outfit":  ("fixed", "outfit_custom",    "Clothing"),
    "camp":    ("fixed", "camp_tent",        "To Camp"),
}


def bottom_variants(slot, src):
    """Every icon/label a bottom-row button can show. The button reports the live order,
    so a Movement button has to carry all seven movement glyphs."""
    if src == "move":
        return [(k, ic, lb) for k, ic, lb in MOVE if k != "return"]
    if src == "form":
        return [(k, ic, lb) for k, ic, lb in FORM if k != "return"]
    if src == "state":
        return toggle_states(slot)
    ent = toggle_states(slot)
    return ent if ent else [FIXED_BUTTON.get(slot, ("fixed", "settings_toggle", "Toggle"))]


def toggle_states(key):
    for k, states in TOGGLE:
        if k == key:
            return states
    return []


# ---------------------------------------------------------------- raster helpers

def aa_canvas(w, h, k=4):
    return Image.new("RGBA", (w * k, h * k), (0, 0, 0, 0)), k


def aa_done(im, w, h):
    return im.resize((w, h), Image.LANCZOS)


def disc(d, rgb, alpha, ring=None, ring_w=0.0):
    """A filled circle, optionally ringed.

    A ringed disc is padded so the ring's glow - Bannerlord's active-order highlight bleeds
    outside the circle - has somewhere to fall.
    """
    pad = int(d * 0.14) if ring else 0
    n_out = d + pad * 2
    im, k = aa_canvas(n_out, n_out)
    g = ImageDraw.Draw(im)
    a, b = pad * k, (pad + d) * k - 1
    g.ellipse([a, b - (d * k - 1), b, b], fill=(0, 0, 0, 0))     # no-op, keeps bbox explicit
    g.ellipse([a, a, b, b], fill=tuple(rgb) + (int(255 * alpha),))
    if ring:
        rw = max(1, int(ring_w * k))
        glow = Image.new("RGBA", im.size, (0, 0, 0, 0))
        ImageDraw.Draw(glow).ellipse([a, a, b, b], outline=tuple(ring) + (175,),
                                     width=rw * 2)
        glow = glow.filter(ImageFilter.GaussianBlur(rw * 1.8))
        im = Image.alpha_composite(im, glow)
        ImageDraw.Draw(im).ellipse([a + rw // 2, a + rw // 2, b - rw // 2, b - rw // 2],
                                   outline=tuple(ring) + (255,), width=rw)
    return aa_done(im, n_out, n_out)


def rounded(w, h, r, rgb, alpha, edge=None, edge_w=0.0):
    im, k = aa_canvas(w, h)
    g = ImageDraw.Draw(im)
    g.rounded_rectangle([0, 0, w * k - 1, h * k - 1], radius=int(r * k),
                        fill=tuple(rgb) + (int(255 * alpha),))
    if edge:
        ew = max(1, int(edge_w * k))
        g.rounded_rectangle([ew // 2, ew // 2, w * k - 1 - ew // 2, h * k - 1 - ew // 2],
                            radius=int(r * k), outline=tuple(edge) + (255,), width=ew)
    return aa_done(im, w, h)


def solid(w, h, rgb, alpha=1.0):
    return Image.new("RGBA", (max(1, w), max(1, h)), tuple(rgb) + (int(255 * alpha),))


_fonts = {}


def font(px):
    if px not in _fonts:
        _fonts[px] = ImageFont.truetype(FONT_UI, px)
    return _fonts[px]


def text_img(s, px, rgb, shadow=True, face="bold", tracking=0.0):
    """A label in the game's own UI typeface, with the dark halo Bannerlord uses to keep text
    legible over any terrain. `px` stays a Segoe-equivalent cap height so the layout constants
    tuned before the font swap still mean what they did."""
    ink = kcd_font.text(s, px * KCD_CAP, rgb, font=face, tracking=tracking * px)
    bb = ink.split()[3].getbbox()
    if bb is None:
        return ink
    ink = ink.crop(bb)
    pad = 3 * SS          # constant in stage units, so every size starts on one rail
    im = Image.new("RGBA", (ink.size[0] + pad * 2, ink.size[1] + pad * 2), (0, 0, 0, 0))
    if shadow:
        sh = Image.new("RGBA", im.size, (0, 0, 0, 0))
        sh.paste(Image.new("RGBA", ink.size, (0, 0, 0, 210)), (pad, pad), ink)
        sh = sh.filter(ImageFilter.GaussianBlur(max(1, px / 9.0)))
        im = Image.alpha_composite(im, sh)
        im = Image.alpha_composite(im, sh)
    top = Image.new("RGBA", im.size, (0, 0, 0, 0))
    top.paste(ink, (pad, pad), ink)
    return Image.alpha_composite(im, top)


# ---------------------------------------------------------------- key caps
#
# KCD2's own key-cap art, not an imitation of it. Everything below is measured out of
# Libs/UI/buttons.gfx and its textures rather than eyeballed off a screenshot:
#
#   the art      Textures/buttons/key.dds is 64x64 and drawn 64 wide; key_middle and
#                key_long share one 128x64 texture drawn 95 and 115 wide.
#   the letter   DefineEditText id=103 sets it at font height 600 twips = 30px on that
#                64px cap, colour (0,0,0,255), centre aligned.
#   the letter's y   the cap's light face is rows 5..48 of 64 - the tan band under it is
#                the key's front edge, seen slightly from above - so the ink centres at
#                0.414 of the cap height, not at the middle.
#
# The three .dds files are copied into assets/ui/keycaps so a rebuild does not need the
# game installed.

KEYCAPS = os.path.join(ROOT, "assets", "ui", "keycaps")
# hud.gfx is a 1920x1080 stage and places the buttons movie at scale 0.5, so a 64px cap
# draws 32px there = 21.33 of our 1280-wide units - which is exactly its 64 authored
# pixels at ss=3. Drawing it at its native size means no resampling anywhere.
HUD_SCALE = 1280.0 / 1920.0
KEYCAP_H = 64.0 / SS                            # 21.33 stage units
KEYCAP_EM = 30.0 / 64.0                         # font em as a fraction of cap height
KEYCAP_INK_Y = 0.414                            # ink centre, as a fraction of cap height
KEYCAP_W = {"key": 64.0 / 64.0, "key_middle": 95.0 / 64.0, "key_long": 115.0 / 64.0}
# The label beside it: mc_ApseTopRightActionHint sets DefaultFont at 22px, pure white.
HINT_LBL_EM = 22.0 * HUD_SCALE                  # 14.67 stage units
HINT_LBL_RGB = (255, 255, 255)
HINT_LBL_FACE = "body"                          # DefaultFont - the regular face, not bold

_keycap_src = {}


def _keycap_art(kind):
    if kind not in _keycap_src:
        p = os.path.join(KEYCAPS, kind + ".dds")
        if not os.path.exists(p):
            raise SystemExit("missing %s - copy it from the game's "
                             "Libs/UI/Textures/buttons" % p)
        _keycap_src[kind] = Image.open(p).convert("RGBA")
    return _keycap_src[kind]


def _dekey_shadow(im, floor=40):
    """Drop the soft dark fringe the texture carries around the cap.

    The cap is not cut out cleanly: a couple of pixels of dark, barely-opaque edge run all
    the way round it, and at the sizes a prompt is drawn that reads as a drop shadow.

    Only the alpha needs touching. The SWF encoder stores bitmaps ALPHA-PREMULTIPLIED, so
    whatever RGB sits under a transparent pixel is multiplied away at build time and can
    never smear back out at runtime - which is why there is no colour-bleed pass here.
    """
    im = im.copy()
    px = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            if px[x, y][3] < floor:
                px[x, y] = (0, 0, 0, 0)
    return im


def keycap(label, h):
    """One key cap, `h` authored pixels tall, with its letter baked on."""
    kind = "key" if len(label) == 1 else ("key_middle" if len(label) <= 3 else "key_long")
    w = int(round(h * KEYCAP_W[kind]))
    cap = _dekey_shadow(_keycap_art(kind))
    if (w, int(h)) != cap.size:
        cap = cap.resize((w, int(h)), Image.LANCZOS)

    ink = kcd_font.text(label, h * KEYCAP_EM, HINT_BTN_TEXT, font="bold")
    bb = ink.split()[3].getbbox()
    if bb:
        ink = ink.crop(bb)
    x = (w - ink.size[0]) // 2
    y = int(round(h * KEYCAP_INK_Y - ink.size[1] / 2.0))
    out = cap.copy()
    out.alpha_composite(ink, (max(0, x), max(0, y)))
    return out


def vignette(n, k=256):
    """The soft dark blob the radial menu sits on.

    The falloff is computed rather than taken from Image.radial_gradient, which normalises
    by the corner distance and so still has alpha left at the edge midpoints - that reads as
    a soft-edged RECTANGLE over a bright sky, which is exactly what it must not look like.
    Built small and resized up; the gradient is smooth enough that nothing is lost.
    """
    a = Image.new("L", (k, k))
    px = a.load()
    c = (k - 1) / 2.0
    for y in range(k):
        dy = (y - c) / c
        for x in range(k):
            d = min(1.0, math.hypot((x - c) / c, dy))
            px[x, y] = int(255 * ((1.0 - d) ** 3.2) * 0.40)
    im = Image.new("RGBA", (n, n), (6, 7, 9, 255))
    im.putalpha(a.resize((n, n), Image.BICUBIC))
    return im


# ---------------------------------------------------------------- glyphs

_glyph_cache = {}
MISSING = []


def placeholder(name, n):
    """Stand-in art for a glyph the icon set does not have yet.

    Drawn in the same warm white as the real glyphs so the UI reads correctly; the build
    reports every one so they are easy to find and replace.
    """
    im, k = aa_canvas(n, n)
    g = ImageDraw.Draw(im)
    s = n * k
    c = tuple(GLYPH) + (255,)
    if name == "no_engage":
        # a sheathed blade struck through: "do not attack"
        g.polygon([(s * .46, s * .10), (s * .54, s * .10), (s * .54, s * .62),
                   (s * .50, s * .72), (s * .46, s * .62)], fill=c)
        g.rectangle([s * .33, s * .60, s * .67, s * .67], fill=c)
        g.line([(s * .16, s * .84), (s * .84, s * .16)], fill=c, width=int(s * .085))
    else:
        g.ellipse([s * .16, s * .16, s * .84, s * .84], outline=c, width=int(s * .08))
        g.line([(s * .34, s * .34), (s * .66, s * .66)], fill=c, width=int(s * .08))
    return aa_done(im, n, n)


def glyph(name, n, rgb=GLYPH):
    """Load an icon, normalise it to a flat silhouette and fit it into an n x n box."""
    key = (name, n, rgb)
    if key in _glyph_cache:
        return _glyph_cache[key]
    path = os.path.join(ICONS, name + ".png")
    if not os.path.exists(path):
        path = os.path.join(ICONS_ALT, name + ".png")
    if not os.path.exists(path):
        if name not in MISSING:
            MISSING.append(name)
        im = placeholder(name, n)
        _glyph_cache[key] = im
        return im
    src = Image.open(path).convert("RGBA")
    a = src.getchannel("A")
    if a.getextrema()[0] == 255:            # no real alpha - derive the mask from luminance
        a = src.convert("L")
    # These are generated rasters and 48 of the 50 carry a faint halo of near-transparent
    # pixels well outside the glyph. A raw getbbox() includes that halo and centres the icon
    # on it instead of on the ink - measured at up to 123px of 1254, which reads as a visibly
    # off-centre glyph in the button. Take the box from a thresholded copy, then crop the real
    # alpha to it so soft edges inside the glyph survive.
    bb = a.point(lambda v: 255 if v > GLYPH_ALPHA_FLOOR else 0).getbbox() or a.getbbox()
    if bb:
        a = a.crop(bb)
    # fit inside the box, preserving aspect, with a hair of margin
    box = int(n * 0.94)
    w, h = a.size
    sc = min(box / float(w), box / float(h))
    a = a.resize((max(1, int(w * sc)), max(1, int(h * sc))), Image.LANCZOS)
    out = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    flat = Image.new("RGBA", a.size, tuple(rgb) + (255,))
    flat.putalpha(a)
    out.paste(flat, ((n - a.size[0]) // 2, (n - a.size[1]) // 2))
    _glyph_cache[key] = out
    return out


# ---------------------------------------------------------------- SWF assembly

def define_sprite_at(sprite_id, shape_id, ox, oy):
    inner = M.place(shape_id, 1, "s", ox, oy) + M.do_action_stop() + M.tag(1, b"") + M.tag(0, b"")
    return M.tag(39, struct.pack("<HH", sprite_id, 1) + inner)


def place_scaled(char_id, depth, name, tx, ty, s):
    flags = 0x20 | 0x04 | 0x02
    body = bytes([flags]) + struct.pack("<H", depth) + struct.pack("<H", char_id)
    body += M.matrix_full(s, s, tx * M.TWIP, ty * M.TWIP)
    body += name.encode("ascii") + b"\x00"
    return M.tag(26, body)


PARK = -3000        # clips start off-stage so nothing flashes before Lua lays them out


class Atlas:
    """Every visual is a bitmap wrapped in a named sprite.

    Sprites share shapes and shapes share bitmaps, so the 500-odd clips this UI needs cost
    about 50 unique images. Clips are centre-registered unless asked otherwise, which is
    what a radial menu and a row of circles want.
    """

    def __init__(self):
        self.tags = bytearray()
        self.tags += M.tag(69, struct.pack("<I", 0))
        self.tags += M.tag(9, bytes((10, 10, 12)))
        self.cid, self.depth = 1, 1
        self.shapes = {}
        self.names, self.meta, self.art = [], {}, {}

    def shape(self, key, img=None):
        if key in self.shapes:
            return self.shapes[key]
        if img is None:
            raise KeyError("no art registered for %r" % (key,))
        bid = self.cid; self.cid += 1
        bits, w, h = M.define_bits_lossless2(bid, img)
        self.tags += bits
        sid = self.cid; self.cid += 1
        self.tags += M.define_shape_bitmap(sid, bid, w, h)
        self.shapes[key] = (sid, w, h)
        self.art[key] = img
        return self.shapes[key]

    def add(self, name, key, img=None, center=True):
        sid, w, h = self.shape(key, img)
        spid = self.cid; self.cid += 1
        ox, oy = (-(w // 2), -(h // 2)) if center else (0, 0)
        self.tags += define_sprite_at(spid, sid, ox, oy)
        self.tags += place_scaled(spid, self.depth, name, PARK, PARK, 1.0 / SS)
        self.depth += 1
        self.names.append(name)
        # The driver has to know where a clip's registration point is: centred clips are
        # positioned by their middle, the rest by their top-left corner.
        self.meta[name] = (w / float(SS), h / float(SS), key, center)
        return name

    def write(self, swf_path, xml_path, element):
        tags = bytes(self.tags) + M.do_action_stop() + M.tag(1, b"") + M.tag(0, b"")
        header = M.rect(0, STAGE_W * M.TWIP, 0, STAGE_H * M.TWIP)
        header += struct.pack("<H", 24 << 8) + struct.pack("<H", 1)
        body = header + tags
        swf = b"FWS" + bytes([8]) + struct.pack("<I", 8 + len(body)) + body
        os.makedirs(os.path.dirname(swf_path), exist_ok=True)
        with open(swf_path, "wb") as f:
            f.write(swf)
        M.write_xml(xml_path, element, element, self.names)
        return swf


# ---------------------------------------------------------------- build

def px(u):
    """Stage units -> supersampled bitmap pixels."""
    return max(1, int(round(u * SS)))


def build():
    A = Atlas()
    bd, wd = L["btnD"], L["wheelD"]
    ring_w = 1.9

    # --- shared art -----------------------------------------------------------
    A.shape("disc_plain", disc(px(bd), DISC_PLAIN, DISC_PLAIN_A))
    A.shape("disc_on", disc(px(bd), DISC_ON, DISC_ON_A, RING_GOLD, px(ring_w)))
    A.shape("wdisc_plain", disc(px(wd), DISC_PLAIN, DISC_PLAIN_A))
    A.shape("wdisc_on", disc(px(wd), DISC_ON, DISC_ON_A, RING_GOLD, px(ring_w)))
    A.shape("chip", rounded(px(19), px(14), px(3), CHIP_BG, 0.96))
    A.shape("card", rounded(px(L["cardW"]), px(L["cardH"]), px(8), CARD_FILL, CARD_FILL_A,
                            CARD_EDGE, px(1.8)))
    A.shape("card_sel", rounded(px(L["cardW"]), px(L["cardH"]), px(8), CARD_FILL_SEL,
                                CARD_FILL_SEL_A, CARD_EDGE_SEL, px(2.0)))
    A.shape("card_chip", rounded(px(19), px(19), px(3), CHIP_BG, 0.96,
                                 (40, 36, 30), px(1.2)))
    A.shape("hp_bg", solid(px(L["cardHpW"]), px(L["cardHpH"]), HP_BG, 0.85))
    A.shape("hp_dead", solid(px(L["cardHpW"]), px(L["cardHpH"] - 2), HP_DEAD, 0.95))
    for k, col in (("g", HP_GOOD), ("a", HP_WARN), ("r", HP_BAD)):
        A.shape("hp_" + k, solid(px(L["cardHpW"]), px(L["cardHpH"] - 2), col, 0.95))
    A.shape("vig", vignette(px(L["vig"])))

    for k in KEY_POOL:
        A.shape("key_" + k, text_img(k, px(9), CHIP_TEXT, shadow=False))

    # The corner prompt's key cap: the game's own texture with the letter baked on.
    for k in KEY_POOL:
        A.shape("hbtn_" + k, keycap(k, px(KEYCAP_H)))

    # --- z-order: vignette, cards, bottom row, wheel --------------------------
    A.add("vig", "vig")

    # The letter is baked into the cap, so a prompt is two clips and not three.
    for k in KEY_POOL:
        A.add("hint_btn_" + k, "hbtn_" + k)
    A.add("hint_lbl", "hint_lbl_art",
          text_img("Command", px(HINT_LBL_EM), HINT_LBL_RGB, face=HINT_LBL_FACE))
    A.add("hint_lbl_close", "hint_lbl_close_art",
          text_img("Close", px(HINT_LBL_EM), HINT_LBL_RGB, face=HINT_LBL_FACE))

    for i in range(1, 6):
        p = "c%d_" % i
        A.add(p + "plate", "card", center=False)
        A.add(p + "sel", "card_sel", center=False)
        for t in TROOP_TYPES:
            A.add(p + "wm_" + t, "wm_" + t, glyph(TROOP_ICON[t], px(46)))
        for t in TROOP_TYPES:
            A.add(p + "ty_" + t, "ty_" + t, glyph(TROOP_ICON[t], px(21)))
        for d in range(10):
            A.add(p + "d0_%d" % d, "dig_%d" % d, text_img(str(d), px(17), LABEL))
        for d in range(10):
            A.add(p + "d1_%d" % d, "dig_%d" % d)
        A.add(p + "hpbg", "hp_bg", center=False)
        for k in ("g", "a", "r"):
            A.add(p + "hp_" + k, "hp_" + k, center=False)
        A.add(p + "hp_dead", "hp_dead", center=False)
        A.add(p + "chip", "card_chip")
        A.add(p + "num", "cnum_%d" % i, text_img(str(i), px(12), CHIP_TEXT, shadow=False))
        for key, icon in CARD_STATES:
            A.add(p + "o_" + key, "ord_" + key, glyph(icon, px(16)))

    for i, (slot, src, _title) in enumerate(BOTTOM, 1):
        p = "b%d_" % i
        A.add(p + "disc", "disc_plain")
        A.add(p + "ring", "disc_on")
        for k, icon, lbl in bottom_variants(slot, src):
            A.add(p + "i_" + k, "g_%s_b" % icon, glyph(icon, px(29)))
            A.add(p + "t_" + k, "lbl_%s" % lbl, text_img(lbl, px(9), LABEL))
        A.add(p + "chip", "chip")
        for k in KEY_POOL:
            A.add(p + "k_" + k, "key_" + k)

    slots = max([len(v) for v in SIMPLE_WHEELS.values()]
                + [len(v) for v in STATE_WHEELS.values()])
    for j in range(1, slots + 1):
        p = "w%d_" % j
        A.add(p + "disc", "wdisc_plain")
        A.add(p + "ring", "wdisc_on")
        for cat, items in sorted(SIMPLE_WHEELS.items()):
            if j <= len(items):
                k, icon, lbl = items[j - 1]
                A.add(p + "i_%s_%s" % (cat, k), "g_%s_w" % icon, glyph(icon, px(23)))
                A.add(p + "t_%s_%s" % (cat, k), "lbl_%s" % lbl, text_img(lbl, px(9), LABEL))
        for cat, ent in sorted(STATE_WHEELS.items()):
            if j <= len(ent):
                slot, states = ent[j - 1]
                for k, icon, lbl in states:
                    A.add(p + "i_%s_%s_%s" % (cat, slot, k), "g_%s_w" % icon,
                          glyph(icon, px(23)))
                    A.add(p + "t_%s_%s_%s" % (cat, slot, k), "lbl_%s" % lbl,
                          text_img(lbl, px(9), LABEL))
        A.add(p + "chip", "chip")
        for k in KEY_POOL:
            A.add(p + "k_" + k, "key_" + k)

    return A


# ---------------------------------------------------------------- Lua emit

def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def write_lua(path, A):
    o = ["-- GENERATED by tools/make_bl.py - do not edit by hand.",
         "-- Clip sizes, layout geometry and the order tree for the Bannerlord-style",
         "-- command UI. See docs/command-ui.md.",
         "",
         "mercenaries.BLAtlas = {",
         "    element = \"MercBL\",",
         "    stageW = %d, stageH = %d," % (STAGE_W, STAGE_H),
         "    ss = %d," % SS,
         "    keys = { %s }," % ", ".join(lua_str(k) for k in KEY_POOL),
         "    bind = { %s }," % ", ".join(
             "{ %s, %s }" % (lua_str(a), lua_str(b)) for a, b in BIND),
         "    hideKey = { %s, %s }," % (lua_str(HIDE_KEY[0]), lua_str(HIDE_KEY[1])),
         "    returnSlot = %d," % RETURN_SLOT,
         "    outfitPage = %d," % OUTFIT_PAGE,
         "    troopTypes = { %s }," % ", ".join(lua_str(t) for t in TROOP_TYPES),
         "    layout = {"]
    for k in sorted(L):
        o.append("        %s = %s," % (k, L[k]))
    o.append("    },")

    o.append("    bottom = {")
    for i, (slot, src, title) in enumerate(BOTTOM, 1):
        vs = ", ".join("{ key = %s, label = %s }" % (lua_str(k), lua_str(lb))
                       for k, _ic, lb in bottom_variants(slot, src))
        o.append("        { slot = %s, src = %s, title = %s, variants = { %s } }," %
                 (lua_str(slot), lua_str(src), lua_str(title), vs))
    o.append("    },")

    o.append("    wheels = {")
    for nm, items in sorted(SIMPLE_WHEELS.items()):
        o.append("        %s = {" % nm)
        for k, _ic, lbl in items:
            o.append("            { key = %s, label = %s }," % (lua_str(k), lua_str(lbl)))
        o.append("        },")
    o.append("    },")

    o.append("    stateWheels = {")
    for nm, ent in sorted(STATE_WHEELS.items()):
        o.append("        %s = {" % nm)
        for slot, states in ent:
            o.append("            { slot = %s, states = {" % lua_str(slot))
            for k, _ic, lbl in states:
                o.append("                { key = %s, label = %s }," % (lua_str(k), lua_str(lbl)))
            o.append("            } },")
        o.append("        },")
    o.append("    },")

    o.append("    size = {")
    for n in sorted(A.meta):
        w, h, _k, _c = A.meta[n]
        o.append("        [%s] = { w = %.2f, h = %.2f }," % (lua_str(n), w, h))
    o.append("    },")
    o.append("}")
    o.append("")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="ascii") as f:
        f.write("\n".join(o))
    return len(A.meta)


# ---------------------------------------------------------------- offline preview

def preview(A, out, open_cat="move", scale=1.5, page=1):
    """Compose the whole UI exactly as the Lua driver will lay it out.

    This is the fast iteration loop: it uses the same art and the same geometry, so what it
    shows is what the game shows, without launching the game.
    """
    W, H = int(STAGE_W * scale), int(STAGE_H * scale)
    bg = Image.new("RGBA", (W, H), (0, 0, 0, 255))
    g = ImageDraw.Draw(bg)
    for y in range(H):                                   # a sky-to-ground gradient
        t = y / float(H)
        if t < 0.62:
            u = t / 0.62
            g.line([(0, y), (W, y)], fill=(int(96 + 70 * u), int(126 + 66 * u), int(168 + 52 * u)))
        else:
            u = (t - 0.62) / 0.38
            g.line([(0, y), (W, y)], fill=(int(96 - 40 * u), int(92 - 36 * u), int(74 - 30 * u)))

    def blit(key, cx, cy, center=True, alpha=1.0, sc=1.0):
        im = A.art[key]
        w = max(1, int(im.size[0] * scale / SS * sc))
        h = max(1, int(im.size[1] * scale / SS * sc))
        im = im.resize((w, h), Image.LANCZOS)
        if alpha < 1.0:
            a = im.getchannel("A").point(lambda v: int(v * alpha))
            im = im.copy(); im.putalpha(a)
        x = int(cx * scale - (w / 2 if center else 0))
        y = int(cy * scale - (h / 2 if center else 0))
        bg.alpha_composite(im, (x, y))

    # the idle hint stands alone: it only shows while the interface is CLOSED
    if open_cat == "hint":
        kn = HIDE_KEY[1]
        bw = A.art["hbtn_" + kn].size[0] / float(SS)
        lw = A.art["hint_lbl_art"].size[0] / float(SS)
        x = L["hintEdge"]
        blit("hbtn_" + kn, x - bw / 2, L["hintY"])
        blit("hint_lbl_art", x - bw - L["hintGap"] - lw / 2, L["hintY"])
        os.makedirs(os.path.dirname(out), exist_ok=True)
        bg.convert("RGB").save(out, quality=94)
        return out

    # squad cards
    demo = [("infantry", 12, 1.00, "charge"), ("infantry", 11, 0.82, "move"),
            ("archer", 9, 0.55, "camp"), ("archer", 8, 0.30, "follow")]
    for i, (ty, cnt, hp, order) in enumerate(demo, 1):
        y = L["cardY0"] + (i - 1) * L["cardPitch"]
        sel = (i == 1)
        blit("card_sel" if sel else "card", L["cardX"], y, center=False)
        blit("wm_" + ty, L["cardX"] + L["cardW"] / 2.0, y + L["cardH"] / 2.0 + L["cardWmDY"],
             alpha=0.16)
        blit("ty_" + ty, L["cardX"] + L["cardIconDX"], y + L["cardIconDY"])
        s = str(cnt)
        for di, ch in enumerate(s):
            blit("dig_" + ch, L["cardX"] + L["cardCountDX"] + di * 10, y + L["cardCountDY"])
        hy = y + L["cardH"] + L["cardHpDY"]
        blit("hp_bg", L["cardX"] + 8, hy, center=False)
        band = "g" if hp > 0.6 else ("a" if hp > 0.3 else "r")
        im = A.art["hp_" + band]
        w = max(1, int(im.size[0] * scale / SS * hp)); h = max(1, int(im.size[1] * scale / SS))
        bg.alpha_composite(im.resize((w, h), Image.LANCZOS),
                           (int((L["cardX"] + 8) * scale), int((hy + 1) * scale)))
        blit("card_chip", L["cardX"] + L["cardChipDX"], y + L["cardH"] / 2.0)
        blit("cnum_%d" % i, L["cardX"] + L["cardChipDX"], y + L["cardH"] / 2.0)
        blit("ord_" + order, L["cardX"] + L["cardW"] / 2.0, y + L["cardH"] + L["cardOrderDY"])

    # bottom row
    n = len(BOTTOM)
    x0 = STAGE_W / 2.0 - (n - 1) * L["btnPitch"] / 2.0
    state = {"move": ("follow", "Follow Me"), "form": ("line", "Line"),
             "toggle": ("fixed", "Toggle"), "weapons": ("fixed", "Weapons"),
             "outfit": ("fixed", "Clothing"), "camp": ("fixed", "To Camp")}
    on = {}
    openi = [i for i, (s_, _, _) in enumerate(BOTTOM, 1) if s_ == open_cat]
    openi = openi[0] if openi else 0
    for i, (slot, src, _t) in enumerate(BOTTOM, 1):
        cx = x0 + (i - 1) * L["btnPitch"]
        cy = L["rowY"]
        sc = L["btnOpenScale"] if i == openi else 1.0
        lit = on.get(slot, False) or i == openi
        blit("disc_on" if lit else "disc_plain", cx, cy, sc=sc)
        k, lbl = state[slot]
        ic = dict((a, b) for a, b, _ in bottom_variants(slot, src))[k]
        blit("g_%s_b" % ic, cx, cy, sc=sc)
        blit("lbl_%s" % lbl, cx, cy + L["btnLabelDY"])
        # While a wheel is open the F-keys address the wheel, so the row drops its badges.
        if open_cat is None:
            blit("chip", cx, cy + L["btnBadgeDY"])
            blit("key_" + BIND[i - 1][1], cx, cy + L["btnBadgeDY"])

    # the corner prompt, which speaks in both states
    kn = HIDE_KEY[1]
    bw = A.art["hbtn_" + kn].size[0] / float(SS)
    lbl_art = "hint_lbl_close_art"
    lw = A.art[lbl_art].size[0] / float(SS)
    hx, hy = L["hintEdge"], L["hintY"]              # unmoved: this screen does not dodge
    blit("hbtn_" + kn, hx - bw / 2, hy)
    blit(lbl_art, hx - bw - L["hintGap"] - lw / 2, hy)

    # open wheel
    cat = {"move": "move", "form": "form", "toggle": "tog",
           "weapons": "wpnm", "outfit": "outfit"}.get(open_cat)
    items = []
    if cat in SIMPLE_WHEELS:
        items = [(k, ic, lb) for k, ic, lb in SIMPLE_WHEELS[cat]]
    elif cat in STATE_WHEELS:
        # Paged wheels put a different entry in each slot, so mirror the driver's indexing
        # rather than showing states[0] five times over.
        for i, (slot, states) in enumerate(STATE_WHEELS[cat], 1):
            if cat == "outfit" and slot not in ("more", "return"):
                o = states[(page - 1) * OUTFIT_PAGE + i - 1] if                     (page - 1) * OUTFIT_PAGE + i - 1 < len(states) else None
                if o is None:
                    continue
                items.append((o[0], o[1], o[2]))
            else:
                items.append((slot, states[0][1], states[0][2]))
    if not items:
        os.makedirs(os.path.dirname(out), exist_ok=True)
        bg.convert("RGB").save(out, quality=94)
        return out
    cx0 = x0 + (openi - 1) * L["btnPitch"]
    cy0 = L["rowY"] + L["wheelDY"]
    blit("vig", cx0, cy0)
    cnt = len(items)
    for j, (k, ic, lbl) in enumerate(items):
        a = -math.pi / 2 + 2 * math.pi * j / cnt
        cx = cx0 + math.cos(a) * L["wheelR"]
        cy = cy0 + math.sin(a) * L["wheelR"]
        sel = (j == 0)
        sc = L["wheelSelScale"] if sel else 1.0
        blit("wdisc_on" if sel else "wdisc_plain", cx, cy, sc=sc)
        blit("g_%s_w" % ic, cx, cy, sc=sc)
        blit("lbl_%s" % lbl, cx, cy + L["wheelLabelDY"])
        blit("chip", cx, cy + L["wheelBadgeDY"])
        ki = RETURN_SLOT if j == cnt - 1 else j + 1
        blit("key_" + BIND[ki - 1][1], cx, cy + L["wheelBadgeDY"])

    os.makedirs(os.path.dirname(out), exist_ok=True)
    bg.convert("RGB").save(out, quality=94)
    return out


if __name__ == "__main__":
    A = build()
    swf_path = os.path.join(ROOT, "data", "libs", "UI", "MercBL.swf")
    xml_path = os.path.join(ROOT, "data", "libs", "UI", "UIElements", "MercBL.xml")
    lua_path = os.path.join(ROOT, "data", "Scripts", "mods", "mercenaries_blatlas.lua")
    swf = A.write(swf_path, xml_path, "MercBL")
    n = write_lua(lua_path, A)
    print("MercBL.swf   %.1f KB, %d clips, %d unique images"
          % (len(swf) / 1024.0, len(A.names), len(A.shapes)))
    print("MercBL.xml   %d MovieClips" % len(A.names))
    print("blatlas.lua  %d clip sizes" % n)
    if MISSING:
        print("PLACEHOLDER art used for: %s" % ", ".join(MISSING))
    if "--preview" in sys.argv:
        for cat in ("hint", None, "move", "form", "toggle", "weapons", "outfit"):
            p = preview(A, os.path.join(ROOT, "tools", "out", "blui_%s.png" % (cat or "idle")), cat)
            print("preview ->", p)
