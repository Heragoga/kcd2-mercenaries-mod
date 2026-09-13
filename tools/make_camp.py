"""Build the camp screen: MercCamp.swf, its UIElements XML and the Lua layout table.

Same machinery as the command interface - tools/make_bl.py owns the Atlas, the glyph loader
and the raster helpers, and this reuses all of it so the two screens are one visual system.

Where the command interface shows squads down the left edge, this shows the company's
improvements: what is standing, what has been bought and not yet placed, and what is still
for sale. The bottom row is one button per improvement, paged, with a wheel of actions.

    python tools/make_camp.py --preview
"""
import io, os, re, sys, math, struct

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_bl as B
from make_bl import (Atlas, glyph, text_img, disc, rounded, solid, vignette, px,
                     STAGE_W, STAGE_H, SS, LABEL, GLYPH, CHIP_BG, CHIP_TEXT,
                     DISC_PLAIN, DISC_PLAIN_A, DISC_ON, DISC_ON_A, RING_GOLD,
                     CARD_FILL, CARD_FILL_A, CARD_EDGE, CARD_FILL_SEL, CARD_FILL_SEL_A,
                     CARD_EDGE_SEL, HP_GOOD, HP_WARN, HP_BAD, lua_str)
from PIL import Image, ImageDraw

ROOT = B.ROOT

# Status colours for the improvement list. Deliberately not the health-bar palette: these
# say "what state is this in", not "how hurt is it".
# Ranked by how much you own of it: what stands in the camp reads strongest, what you have
# not bought reads weakest. These were the wrong way round, so the two states you did NOT
# own were the brightest marks on the screen.
ST_BUILT   = (128, 158, 94)     # standing in the camp
ST_OWNED   = (150, 118, 54)     # paid for, not placed
ST_UNOWNED = (92, 88, 80)       # still for sale
DIM_INK    = (178, 172, 158)    # an action that cannot be taken right now: dimmer than
                                # the live labels, but still legible against bright sky

L = dict(
    # Header, top left, clear of KCD2's own compass at top centre.
    hx=26, panelY=20, hTitleY=42, hStatY=74, hStat2Y=74, hCampY=100, hAutoY=124,
    # The improvement list. Tight: fourteen rows and a header sit above the corner hint.
    listY0=172, listPitch=29, listIconDX=14, listNameDX=34,
    # The status square sits on a fixed column so the squares line up down the panel; the
    # word after it is free to be whatever length it is.
    listPillDX=208, listCountDX=192, listW=300, listH=572,
    # Bottom row and wheel, identical geometry to the command interface so the two screens
    # feel like one thing.
    rowY=566, btnPitch=68, btnD=55,
    btnBadgeDY=-32, btnLabelDY=38, btnOpenScale=1.18,
    wheelDY=-166, wheelR=86, wheelD=41,
    wheelBadgeDY=-21, wheelLabelDY=31, wheelSelScale=1.14,
    # Logistics mode adds a second panel down the right edge. The bottom row is only five
    # discs wide in that mode, so this panel can run the full height without meeting it.
    bX=954, bW=300, bH=286, bTitleY=52, bListY0=96, bPitch=44, bIconDX=22, bNameDX=42,
    bBonusDY=15,
    graphY=430, graphH=118, graphW=252, graphDX=24, graphLabelDY=18,
    statY0=92, statSectPitch=26, statPitch=32, statIconDX=14, statNameDX=34, statValDX=222,
    moraleBarW=250, moraleBarH=9,
    # First row of the prompt column, with the command interface's under it. The anchors
    # are the same as make_bl.py's so the pair stays one column wherever it is put, and
    # every one of them is the row's RIGHT EDGE; hintRowDY 0 is what puts this one on top.
    hintEdge=1262, hintY=32, hintGap=7,
    hintRightX=1262, hintLeftX=200, hintTopY=32, hintBottomY=618,
    hintCompassX=865,
    hintRowDY=0,
)

# key, icon, label, cost field. Order is the order they appear.
IMPROVEMENTS = [
    ("cart",       "food_cart",        "Food Cart",        "UpgFoodCartCost"),
    ("inn",        "makeshift_tavern", "Tavern",           "UpgInnCost"),
    ("hunter",     "hunting_spot",     "Hunter's Station", "UpgHunterCost"),
    ("smithy",     "smithy",           "Smithy",           "UpgSmithyCost"),
    ("alchemy",    "alchemy_bench",    "Alchemy Bench",    "UpgAlchemyCost"),
    ("practice",   "practice_yard",    "Practice Yard",    "UpgPracticeCost"),
    ("house",      "player_house",     "Player House",     "UpgHouseCost"),
    ("circle",     "tent_circle",      "Tent Circle",      None),
    ("tower",      "archer_tower",     "Archer Tower",     "UpgTowerCost"),
    ("archercart", "archer_cart",      "Archer Cart",      "UpgArcherCartCost"),
    ("tent",       "player_tent",      "Player Tent",      None),
    ("wall",       "palisade",         "Palisade",         "UpgWallCost"),
    ("stonewall",  "stone_wall",       "Stone Wall",       "UpgCastleWallCost"),
    ("gate",       "gate",             "Gate",             "UpgGateCost"),
]

# What a button offers. Buy is hidden once owned, Relocate once placed - the driver picks,
# the atlas carries all of them.
# The camp screen answers to its own key: H already belongs to the battle interface, and
# two screens on one key would mean the key could not say which it opens.
#
# Only three letters are unbound anywhere in keybindSuperactions.xml - H, U and Y - and Y is
# no good for a key with a badge drawn on it: engine key names are US scancodes, so engine
# `y` is the top-row key a German keyboard prints as Z, and the badge would contradict the
# keycap. U prints the same on both layouts, and sits next to H.
CAMP_KEY = ("u", "U")

# The bottom row reads left to right as the number row, which is the only mapping nobody has
# to learn. Wheel spokes number themselves 1..N; the row is inert while a wheel is open, so
# the two can share keys without colliding.
ROWKEYS = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]
WHEELKEYS = ["1", "2", "3", "4", "5"]
WHEEL_SLOTS = 6        # fixed positions, so Return sits in one place in every wheel

ACTIONS = [
    ("buy",      "buy_upgrade",       "Buy"),
    ("build",    "construct_upgrade", "Construct"),
    ("relocate", "relocate_upgrade",  "Relocate"),
    ("remove",   "remove_upgrade",    "Remove"),
    ("return",   "return",     "Return"),
]

# ---------------------------------------------------------------- logistics mode
#
# The same screen in a second mode. Slot 1 of the bottom row is always the mode toggle, so
# the key that switches modes never moves; the rest of the row is whatever the mode needs.
#
# Every figure and every action below exists in mercenaries_logistics.lua. Nothing here is
# invented for the sake of a tidy panel - a statistic the mod does not track is a statistic
# the screen cannot honestly show.

# Selecting a category has to change something outside the wheel, or the screen teaches that
# the panels answer your selection in one mode and not the other.
LOGI_TOUCHES = {"rations": ("food", "burn"), "drink": ("drink",),
                "wages": ("wagebill",), "coffer": ("coffer", "purse")}

LOGI = [
    ("rations", "logi_rations", "Rations"),
    ("drink",   "logi_drink",   "Drink"),
    ("wages",   "logi_wages",   "Wages"),
    ("coffer",  "logi_coffer",  "War Chest"),
]

# LogiDeliverFood / LogiPanelFood / LogiBuyFood / LogiToggleWithholdWages /
# LogiDepositCoffer / LogiWithdrawCoffer.
LOGI_WHEELS = {
    "rations": [("give", "logi_deliver", "Deliver"), ("take", "logi_take", "Take Back"),
                ("buy", "buy_upgrade", "Buy Food"), ("return", "return", "Return")],
    "drink":   [("give", "logi_deliver", "Deliver"), ("take", "logi_take", "Take Back"),
                ("buy", "buy_upgrade", "Buy Drink"), ("return", "return", "Return")],
    "wages":   [("pay", "logi_wages", "Pay the Men"), ("hold", "logi_hold_wages", "Withhold"),
                ("return", "return", "Return")],
    "coffer":  [("in", "logi_deposit", "Deposit 500"), ("out", "logi_withdraw", "Withdraw All"),
                ("return", "return", "Return")],
}

# What having each upgrade is worth. The text is STATIC on purpose: these are bitmaps, and a
# bitmap cannot have a number written into it at runtime. Anything that actually changes -
# days of supply left, training level - is a `unit` here and is set from digit clips in its
# own right-hand column, the way the header numbers already are.
#
# The wording states the mod's own tunables (UpgFoodCartFeeds 10, UpgHunterFeeds 5,
# UpgSmithyPct 20); if one of those moves, this moves with it.
BONUS = {
    "cart":       ("Feeds ten men daily",        "days"),
    "inn":        ("Drink, and morale with it",  "days"),
    "hunter":     ("Feeds five men daily",       None),
    "smithy":     ("+20% in a fight",            None),
    "alchemy":    ("Draughts for the wounded",   None),
    "practice":   ("The men drill each day",     "pct"),
    "house":      ("Your quarters, not a tent",  None),
    "tower":      ("An archer holds it",         None),
    "archercart": ("Three archers hold it",      None),
    "wall":       ("Palisade around the camp",   None),
    # Still being shaken out, and said so where it is read rather than only in the notes.
    "stonewall":  ("EXPERIMENTAL - stone curtain and gatehouse", None),
    "gate":       ("A way through the palisade", None),
    "circle":     ("Where the men sleep",        None),
    "tent":       ("Your own tent",              None),
}

# Left panel in logistics mode: (section, icon, label). Values come from the driver.
STATS = [
    ("COMPANY",  [("strength", "troop_infantry", "Under arms"),
                  ("injured",  "stat_injured",   "Injured"),
                  ("wagebill", "logi_wages",     "Wages daily")]),
    ("MORALE",   [("morale",   "stat_morale",    "Morale"),
                  ("combat",   "engagement_aggressive", "Combat")]),
    ("SUPPLIES", [("food",     "logi_rations",   "Food"),
                  ("drink",    "logi_drink",     "Drink"),
                  ("burn",     "logi_take",      "Eaten daily")]),
    ("WAR CHEST", [("coffer",  "logi_coffer",    "In the chest"),
                   ("purse",   "logi_wages",     "Your purse")]),
]

GRAPH_DAYS = 14               # matches mercenaries.LogiHistoryDays


def bonus_rows(total):
    """How many upgrade rows to draw, given how many are active.

    Every improvement can be active at once, which is far more than the panel holds. The
    list is cut to what fits above the food graph; when it IS cut, one row's worth is given
    back to the "+N more" line so that line does not land on the graph's heading.
    """
    fit = max(1, int((L["graphY"] - 26 - L["bListY0"]) // L["bPitch"]))
    if total <= fit:
        return fit
    return max(1, fit - 1)

# Characters a figure can be built from, and how many positions one figure gets.
GLYPHS = ([(str(d), str(d)) for d in range(10)]
          + [("comma", ","), ("slash", "/"), ("plus", "+"), ("minus", "-"),
             ("pct", "%"), ("days", "d"), ("space", " ")])
NUMPOS = 8


def numfields():
    """Every figure that can be on screen at the same time as another one."""
    out = ["tiles", "purse", "cost"]
    for _sect, rows in STATS:
        for key, _ic, _lb in rows:
            out.append(key)
    for i in range(1, len(IMPROVEMENTS) + 1):
        out.append("u%d" % i)
        out.append("c%d" % i)          # how many of that improvement stand
    out.append("standing")
    out.append("moreup")
    return out


def costs():
    """Every upgrade price, read out of the mod itself.

    Build mode shows six rows reading FOR SALE, so it has to say what they cost - and a
    price typed in here by hand would quietly disagree with the game the first time one of
    the tunables moved."""
    src = io.open(os.path.join(ROOT, "data", "Scripts", "mods", "mercenaries_logistics.lua"),
                  encoding="utf-8", errors="replace").read()
    found = dict(re.findall(r"mercenaries\.(Upg\w*Cost)\s*=\s*(\d+)", src))
    out = {}
    for key, _ic, _lb, field in IMPROVEMENTS:
        if field:
            assert field in found, "no price in mercenaries_logistics.lua for " + field
            out[key] = int(found[field])
    return out


COST = costs()

# The camp itself sits permanently in slot 2 of the row, because pitching one is the thing
# you need when there is nothing to manage yet - and it must not page away.
CAMP_SLOT = ("camp", "camp_tent", "Camp")
CAMP_WHEEL_OFF = [("pitch", "construct_upgrade", "Pitch Camp"),
                  ("return", "return", "Return")]
# A camp is pitched or it is not; moving it is breaking it and pitching it again, which is
# two presses of the buttons that are already here.
CAMP_WHEEL_ON = [("recall", "logi_deliver", "Call Them In"),
                 ("break", "remove_upgrade", "Break Camp"),
                 ("return", "return", "Return")]

# A second, smaller line under a row button's name. The name already fills the disc, so a
# warning has to go below it rather than into it.
ROW_NOTE = { "stonewall": "EXPERIMENTAL" }

PAGE = 5                      # improvements per row page; slots 1-2 are Mode and Camp.
                              # The row stops at eight because the engine only delivers the
                              # number row as action_qam_1..8 - see mercenaries_campui.lua.
STATUSES = ["built", "owned", "none"]


# ---------------------------------------------------------------- extra art


# ---------------------------------------------------------------- build


# Every icon the screen asks for now ships as artwork; nothing is drawn here any more.
EXTRA = {}


def art(name, n):
    """Pack glyph if there is one, drawn fallback otherwise."""
    packs = ("logistics-icons-v1", "camp-improvements-v2", "upgrade-actions-v1",
             "camp-improvements-v1")
    for d in [B.ICONS, B.ICONS_ALT] + [os.path.join(ROOT, "assets", "ui", q) for q in packs]:
        if os.path.exists(os.path.join(d, name + ".png")):
            keep = B.ICONS
            B.ICONS = d
            try:
                return glyph(name, n)
            finally:
                B.ICONS = keep
    if name in EXTRA:
        return EXTRA[name](n)
    return glyph(name, n)


def pill(w, h, rgb, text):
    """A filled chip. Kept only for the auto-build switch, which IS a toggle and should read
    like one; improvement status uses `status_mark` instead."""
    im = rounded(w, h, int(h * 0.45), rgb, 0.92)
    t = text_img(text, int(h * 0.52), (250, 250, 248), shadow=False)
    im.alpha_composite(t, ((w - t.size[0]) // 2, (h - t.size[1]) // 2))
    return im


def status_mark(rgb, text, dim=False):
    # (the pip is drawn round inside, to match the discs rather than fight them)
    """A small square in the status colour and the word beside it.

    A filled capsule badge reads as a modern settings toggle and fights the reference's
    warm-white-on-dark restraint; a dot and a word does the same job quietly.
    """
    col = (232, 226, 210) if not dim else (150, 146, 138)
    t = text_img(text.upper(), px(9), col, shadow=False)
    d0 = px(7)
    gap = px(6)
    im = Image.new("RGBA", (d0 + gap + t.size[0], max(d0, t.size[1])), (0, 0, 0, 0))
    sq = Image.new("RGBA", (d0, d0), tuple(rgb) + (255,))
    im.alpha_composite(sq, (0, (im.size[1] - d0) // 2))
    im.alpha_composite(t, (d0 + gap, (im.size[1] - t.size[1]) // 2))
    return im


def build():
    A = Atlas()
    bd, wd, ring = L["btnD"], L["wheelD"], 1.9

    A.shape("disc_plain", disc(px(bd), DISC_PLAIN, DISC_PLAIN_A, B.DISC_RIM, px(0.9)))
    A.shape("disc_on", disc(px(bd), DISC_ON, DISC_ON_A, RING_GOLD, px(ring)))
    A.shape("wdisc_plain", disc(px(wd), DISC_PLAIN, DISC_PLAIN_A, B.DISC_RIM, px(0.9)))
    A.shape("wdisc_on", disc(px(wd), DISC_ON, DISC_ON_A, RING_GOLD, px(ring)))
    A.shape("chip", rounded(px(19), px(14), px(3), CHIP_BG, 0.96))
    A.shape("panel", rounded(px(L["listW"]), px(L["listH"]), px(6), (23, 18, 12), 0.88,
                             CARD_EDGE, px(1.6)))
    # Wide and tall enough to stand clear of the row's icon on every side.
    A.shape("rowsel", rounded(px(L["listW"] - 6), px(L["listPitch"] - 1), px(4),
                              CARD_FILL_SEL, CARD_FILL_SEL_A, CARD_EDGE_SEL, px(1.6)))
    for k in B.KEY_POOL:
        A.shape("key_" + k, text_img(k, px(9), CHIP_TEXT, shadow=False))

    # The same key-cap art as make_bl.py, so the two screens' prompts are one column and
    # not two designs.
    for k in B.KEY_POOL:
        A.shape("hbtn_" + k, B.keycap(k, px(B.KEYCAP_H)))
    for st, col, word in (("built", ST_BUILT, "Built"), ("owned", ST_OWNED, "Stored"),
                          ("none", ST_UNOWNED, "For sale")):
        A.shape("pill_" + st, status_mark(col, word, dim=(st == "none")))
        A.shape("dot_" + st, rounded(px(7), px(7), px(3.5), col, 1.0))

    A.add("panel", "panel", center=False)

    # header
    A.add("title", "title_art", text_img("CAMP", px(19), LABEL))
    A.add("lbl_tiles", "lbl_tiles_art", text_img("TILES", px(9), (176, 166, 146)))
    A.add("lbl_purse", "lbl_purse_art", text_img("PURSE", px(9), (176, 166, 146)))
    A.add("lbl_improv", "lbl_improv_art", text_img("IMPROVEMENTS", px(10), (188, 176, 150)))
    for d in range(10):
        A.add("hd0_%d" % d, "dig_%d" % d, text_img(str(d), px(13), LABEL))
    for d in range(10):
        A.add("hd1_%d" % d, "dig_%d" % d)
    for d in range(10):
        A.add("ht0_%d" % d, "digs_%d" % d, text_img(str(d), px(12), LABEL))
    for slot in range(1, 7):
        for d in range(10):
            A.add("hp%d_%d" % (slot, d), "digs_%d" % d)
    # The header numbers are assembled from digit clips at runtime; the preview needs a
    # concrete pair, and shipping them costs nothing.
    A.add("stat_tiles", "stat_tiles_art", text_img("7 / 12", px(13), LABEL))
    A.add("stat_purse", "stat_purse_art", text_img("1,240", px(13), LABEL))
    A.add("lbl_camp", "lbl_camp_art", text_img("CAMP", px(9), (176, 166, 146)))
    A.add("camp_yes", "camp_yes_art", text_img("Pitched", px(13), ST_BUILT))
    A.add("camp_no", "camp_no_art", text_img("None", px(13), ST_UNOWNED))

    # the list: one row per improvement, any of three statuses
    for i, (key, icon, label, _c) in enumerate(IMPROVEMENTS, 1):
        p = "r%d_" % i
        A.add(p + "sel", "rowsel", center=False)
        A.add(p + "ic", "ic_" + icon, art(icon, px(20)))
        A.add(p + "nm", "nm_" + label, text_img(label, px(11), LABEL))
        for st in STATUSES:
            A.add(p + "pill_" + st, "pill_" + st, center=False)

    # bottom row: five improvements plus More, and every improvement can sit in any slot
    ROW_SLOTS = 2 + PAGE + 1
    for slot in range(1, ROW_SLOTS + 1):
        p = "b%d_" % slot
        A.add(p + "disc", "disc_plain")
        A.add(p + "ring", "disc_on")
        for st in STATUSES:
            A.add(p + "dot_" + st, "dot_" + st)
        A.add(p + "chip", "chip")
        for k in B.KEY_POOL:
            A.add(p + "k_" + k, "key_" + k)
        A.add(p + "i_more", "ic_more", art("more", px(29)))
        pages = (len(IMPROVEMENTS) + PAGE - 1) // PAGE
        for pg in range(1, pages + 1):
            A.add(p + "t_more_%d" % pg, "lbl_More_%d_%d" % (pg, pages),
                  text_img("More %d/%d" % (pg, pages), px(9), LABEL))
        for key, icon, label, _c in IMPROVEMENTS:
            A.add(p + "i_" + key, "icb_" + icon, art(icon, px(29)))
            A.add(p + "t_" + key, "lblb_" + label, text_img(label, px(9), LABEL))
            if key in ROW_NOTE:
                A.add(p + "x_" + key, "lblx_" + ROW_NOTE[key],
                      text_img(ROW_NOTE[key], px(7), (214, 168, 78)))

    # the action wheel
    for j in range(1, len(ACTIONS) + 1):
        p = "w%d_" % j
        A.add(p + "disc", "wdisc_plain")
        A.add(p + "ring", "wdisc_on")
        A.add(p + "chip", "chip")
        for k in B.KEY_POOL:
            A.add(p + "k_" + k, "key_" + k)
        key, icon, label = ACTIONS[j - 1]
        A.add(p + "i_" + key, "icw_" + icon, art(icon, px(23)))
        A.add(p + "t_" + key, "lblw_" + label, text_img(label, px(9), LABEL))
        A.add(p + "t_" + key + "_off", "lblw_" + label + "_off",
              text_img(label, px(9), DIM_INK))
        if key == "auto":
            # Auto-build is a toggle, so its spoke shows the state it is in, the way the
            # battle screen's stateful wheels do.
            A.add(p + "i_auto_off", "icw_auto_build_off", art("auto_build_off", px(23)))

    # ---- logistics mode ----
    A.shape("panelB", rounded(px(L["bW"]), px(L["listH"]), px(6), (23, 18, 12), 0.88,
                              CARD_EDGE, px(1.6)))
    A.add("panelB", "panelB", center=False)
    # Build mode has far less to say than the books do, so its panel is half the height
    # rather than a tall box with its lower half empty.
    A.shape("panelD", rounded(px(L["bW"]), px(L["bH"]), px(6), (23, 18, 12), 0.88,
                              CARD_EDGE, px(1.6)))
    A.add("panelD", "panelD", center=False)
    A.add("lbl_bonuses", "lbl_bonuses_art", text_img("ACTIVE UPGRADES", px(10), (188, 176, 150)))
    A.add("lbl_graph", "lbl_graph_art",
          text_img("FOOD, LAST %d DAYS" % GRAPH_DAYS, px(10), (188, 176, 150)))
    A.add("lbl_stats", "lbl_stats_art", text_img("THE COMPANY", px(10), (188, 176, 150)))
    # Build mode's detail panel: the same box as the logistics one, so the two modes have
    # the same mass and the same frame.
    A.add("lbl_detail", "lbl_detail_art", text_img("IMPROVEMENT", px(10), (188, 176, 150)))
    A.add("lbl_standing", "lbl_standing_art", text_img("HOW MANY STAND", px(10), (188, 176, 150)))
    A.add("lbl_moreup", "lbl_moreup_art", text_img("more, not shown", px(9), (150, 144, 130)))
    A.add("lbl_inthecamp", "lbl_inthecamp_art", text_img("in the camp", px(10), LABEL))
    # Fixed words the driver sets next to a figure it assembles from digits.
    for nm, txt2, col in (("groschen", "groschen", (150, 144, 130)),
                          ("free", "Stands with the camp", LABEL),
                          ("onetile", "One tile of the camp", LABEL),
                          ("ago", "%d days ago" % GRAPH_DAYS, (140, 134, 122)),
                          ("today", "today", (140, 134, 122))):
        A.add("lbl_" + nm, "lbl_" + nm + "_art", text_img(txt2, px(9 if nm in
              ("groschen", "ago", "today") else 10), col))
    for st, word, col in (("built", "Built in the camp", ST_BUILT),
                          ("owned", "Bought, not placed", ST_OWNED),
                          ("none", "For sale", ST_UNOWNED)):
        A.add("dst_" + st, "dst_" + st, text_img(word, px(9), col))
    A.shape("statmark", solid(px(3), px(18), RING_GOLD, 0.9))
    A.add("statmark", "statmark", center=False)
    for fld, txt2 in (("cost", "Cost"), ("effect", "Gives")):
        A.add("dl_" + fld, "dl_" + fld + "_art", text_img(txt2, px(9), (176, 166, 146)))
    for key, icon, label, _c in IMPROVEMENTS:
        A.add("d_" + key + "_ic", "dib_" + icon, art(icon, px(64)))
        A.add("d_" + key + "_nm", "dnm_" + label, text_img(label, px(15), LABEL))
    # Value columns are assembled from digit clips, so a figure the mod changes can be shown
    # without re-rendering the atlas. Each number on screen needs its OWN column of
    # instances, one per character position: an instance is what can be moved, so two
    # numbers sharing one - or a single number using the same digit twice, like 500 - would
    # collide and only the last placement would show.
    def figures():
        """Every glyph of a number column, cropped to its ink HORIZONTALLY and to one
        shared box vertically.

        Figures sit on a dark panel and are set solid, so they need none of the halo
        padding a label over open terrain does - that padding is what spaced 500 out into
        5 0 0. But cropping each glyph to its own ink vertically as well throws away the
        baseline, and the driver centres every clip on one y, so a comma - whose ink hangs
        below the baseline - came out floating at mid height and 2,000 read as 2'000.
        kcd_font returns a consistent ascent+descent box, so trim it once for the set.
        """
        raw = {}
        for g, txt in GLYPHS:
            raw[g] = B.kcd_font.text(txt, px(11) * B.KCD_CAP, LABEL, font="bold")
        tops, bots = [], []
        for im in raw.values():
            bb = im.split()[3].getbbox()
            if bb:
                tops.append(bb[1])
                bots.append(bb[3])
        y0, y1 = (min(tops), max(bots)) if tops else (0, 1)
        out = {}
        for g, im in raw.items():
            bb = im.split()[3].getbbox()
            x0, x1 = (bb[0], max(bb[2], bb[0] + 1)) if bb else (0, max(1, im.size[0] - 2))
            out[g] = im.crop((x0, y0, x1, max(y1, y0 + 1)))
        return out

    for g, im in figures().items():
        A.shape("digv_" + g, im)
    for field in numfields():
        for pos in range(1, NUMPOS + 1):
            for g, _t in GLYPHS:
                A.add("n_%s_%d_%s" % (field, pos, g), "digv_" + g)

    for key, icon, label, _c in IMPROVEMENTS:
        p2 = "u_" + key + "_"
        A.add(p2 + "ic", "ic_" + icon)
        A.add(p2 + "nm", "nm_" + label)
        A.add(p2 + "bo", "bonus_" + key,
              text_img(BONUS[key][0], px(9), (168, 160, 144), shadow=False))

    # Morale reads both ways, so its bar is drawn from the middle out and coloured by which
    # way it has gone. The driver scales the fill; these are the full-width masters.
    A.shape("mbar_bg", rounded(px(L["moraleBarW"]), px(L["moraleBarH"]), px(2),
                               (12, 11, 10), 0.92))
    A.shape("mbar_mid", solid(px(1), px(L["moraleBarH"] + 4), (150, 112, 52), 0.9))
    for nm, col in (("good", ST_BUILT), ("warn", HP_WARN), ("bad", HP_BAD)):
        A.shape("mbar_" + nm, solid(px(L["moraleBarW"] // 2), px(L["moraleBarH"]), col, 0.95))
        A.add("mbar_" + nm, "mbar_" + nm, center=False)
    A.add("mbar_bg", "mbar_bg", center=False)
    A.add("mbar_mid", "mbar_mid", center=False)

    # Statistic rows.
    for sect, rows in STATS:
        A.add("sect_" + sect.replace(" ", "_"), "sect_" + sect.replace(" ", "_") + "_art",
              text_img(sect, px(9), (176, 166, 146)))
        for key, icon, label in rows:
            p2 = "s_" + key + "_"
            A.add(p2 + "ic", "sic_" + icon, art(icon, px(17)))
            A.add(p2 + "nm", "snm_" + label, text_img(label, px(10), LABEL))

    # The food graph. One bar clip per column, scaled vertically by the driver - a bitmap
    # cannot be redrawn in game, but it can be stretched, and a bar is the one chart shape
    # that survives being stretched.
    bw = int(L["graphW"] / float(GRAPH_DAYS) * 0.62)
    A.shape("gbar", solid(px(bw), px(L["graphH"]), ST_BUILT, 0.88))
    A.shape("gbar_low", solid(px(bw), px(L["graphH"]), HP_BAD, 0.85))
    A.shape("gbase", solid(px(L["graphW"]), px(1), (96, 90, 78), 0.8))
    A.shape("ggrid", solid(px(L["graphW"]), px(1), (70, 66, 58), 0.55))
    A.add("gbase", "gbase", center=False)
    A.add("ggrid", "ggrid", center=False)
    for i in range(1, GRAPH_DAYS + 1):
        A.add("g%d" % i, "gbar", center=False)
        A.add("g%d_low" % i, "gbar_low", center=False)

    # Bottom row in logistics mode, plus the mode toggle that lives in slot 1 of both modes.
    A.add("camp_ic", "icb_camp_tent", art(CAMP_SLOT[1], px(29)))
    A.add("camp_lbl", "lblb_Camp", text_img("Camp", px(9), LABEL))
    A.add("camp_dib", "dib_camp_tent", art(CAMP_SLOT[1], px(110)))
    A.add("camp_dnm", "dnm_Camp", text_img("The Camp", px(17), LABEL))
    for st, word in (("on", "Pitched here"), ("off", "Not pitched")):
        A.add("camp_st_" + st, "camp_st_" + st,
              text_img(word, px(9), ST_BUILT if st == "on" else ST_UNOWNED))
    for j in range(1, len(CAMP_WHEEL_ON) + 1):
        p2 = "cw%d_" % j
        A.add(p2 + "disc", "wdisc_plain")
        A.add(p2 + "chip", "chip")
        for k in B.KEY_POOL:
            A.add(p2 + "k_" + k, "key_" + k)
        for key, icon, label in CAMP_WHEEL_ON + CAMP_WHEEL_OFF:
            A.add(p2 + "i_" + key, "icw_" + icon, art(icon, px(23)))
            A.add(p2 + "t_" + key, "lblw_" + label, text_img(label, px(9), LABEL))
    A.add("tab_to_logi", "ic_tab_logistics", art("tab_logistics", px(29)))
    A.add("tab_to_build", "ic_tab_build", art("tab_build", px(29)))
    A.add("tab_lbl_logi", "lblb_Logistics", text_img("Logistics", px(9), LABEL))
    A.add("tab_lbl_build", "lblb_Build", text_img("Build", px(9), LABEL))
    for slot in range(1, len(LOGI) + 2):
        p2 = "lb%d_" % slot
        A.add(p2 + "ring", "disc_on")
        A.add(p2 + "disc", "disc_plain")
        A.add(p2 + "ring", "disc_on")
        A.add(p2 + "chip", "chip")
        for k in B.KEY_POOL:
            A.add(p2 + "k_" + k, "key_" + k)
        for key, icon, label in LOGI:
            A.add(p2 + "i_" + key, "icb_" + icon, art(icon, px(29)))
            A.add(p2 + "t_" + key, "lblb_" + label, text_img(label, px(9), LABEL))

    # Logistics wheels: the widest one sets how many spokes have to exist.
    for j in range(1, max(len(v) for v in LOGI_WHEELS.values()) + 1):
        p2 = "lw%d_" % j
        A.add(p2 + "disc", "wdisc_plain")
        A.add(p2 + "ring", "wdisc_on")
        A.add(p2 + "chip", "chip")
        for k in B.KEY_POOL:
            A.add(p2 + "k_" + k, "key_" + k)
        for cat, items in LOGI_WHEELS.items():
            if j <= len(items):
                key, icon, label = items[j - 1]
                A.add(p2 + "i_%s_%s" % (cat, key), "icw_" + icon, art(icon, px(23)))
                A.add(p2 + "t_%s_%s" % (cat, key), "lblw_" + label,
                      text_img(label, px(9), LABEL))
                A.add(p2 + "t_%s_%s_off" % (cat, key), "lblw_" + label + "_off",
                      text_img(label, px(9), DIM_INK))

    # corner hint
    for k in B.KEY_POOL:
        A.add("hint_btn_" + k, "hbtn_" + k)
    A.add("hint_lbl", "hint_lbl_art",
          text_img("Close", px(B.HINT_LBL_EM), B.HINT_LBL_RGB, face=B.HINT_LBL_FACE))
    A.add("hint_lbl_back", "hint_lbl_back",
          text_img("Back", px(B.HINT_LBL_EM), B.HINT_LBL_RGB, face=B.HINT_LBL_FACE))
    A.add("hint_lbl_open", "hint_lbl_open",
          text_img("Camp", px(B.HINT_LBL_EM), B.HINT_LBL_RGB, face=B.HINT_LBL_FACE))
    return A


def write_lua(path, A):
    o = ["-- GENERATED by tools/make_camp.py - do not edit by hand.",
         "-- Clip sizes, layout and the improvement catalogue for the camp screen.",
         "",
         "mercenaries.CampAtlas = {",
         '    element = "MercCamp",',
         "    stageW = %d, stageH = %d," % (STAGE_W, STAGE_H),
         "    ss = %d," % SS,
         "    page = %d," % PAGE,
         # The two rows do not answer to the same keys: the bottom row runs 5..0 across its
         # six slots, while the wheel's last spoke is the back key, so it runs 5..9 then U.
         # The row reads left to right as the number row; wheel spokes number themselves
         # 1..N and the last is always the back key. The row is inert while a wheel is
         # open, so the two can share keys without colliding.
         "    rowBind = { %s }," % ", ".join("{ %s, %s }" % (lua_str(k), lua_str(k))
                                             for k in ROWKEYS),
         "    wheelBind = { %s }," % ", ".join("{ %s, %s }" % (lua_str(k), lua_str(k))
                                               for k in WHEELKEYS),
         "    hideKey = { %s, %s }," % (lua_str(CAMP_KEY[0]), lua_str(CAMP_KEY[1])),
         "    returnSlot = %d," % len(ACTIONS),
         "    layout = {"]
    for k in sorted(L):
        o.append("        %s = %s," % (k, L[k]))
    o.append("    },")
    o.append("    improvements = {")
    for key, _ic, label, cost in IMPROVEMENTS:
        o.append("        { key = %s, label = %s, cost = %s }," %
                 (lua_str(key), lua_str(label), lua_str(cost) if cost else "nil"))
    o.append("    },")
    def tbl(name, rows):
        o.append("    %s = {" % name)
        for key, _ic, label in rows:
            o.append("        { key = %s, label = %s }," % (lua_str(key), lua_str(label)))
        o.append("    },")

    tbl("actions", ACTIONS)
    tbl("logi", LOGI)
    tbl("campWheelOn", CAMP_WHEEL_ON)
    tbl("campWheelOff", CAMP_WHEEL_OFF)
    o.append("    logiWheels = {")
    for cat, items in LOGI_WHEELS.items():
        o.append("        [%s] = {" % lua_str(cat))
        for key, _ic, label in items:
            o.append("            { key = %s, label = %s }," % (lua_str(key), lua_str(label)))
        o.append("        },")
    o.append("    },")
    o.append("    bonus = {")
    for key, (text, unit) in BONUS.items():
        o.append("        [%s] = { text = %s, unit = %s }," %
                 (lua_str(key), lua_str(text), lua_str(unit) if unit else "nil"))
    o.append("    },")
    o.append("    stats = {")
    for sect, rows in STATS:
        o.append("        { section = %s, rows = {" % lua_str(sect))
        for key, icon, label in rows:
            o.append("            { key = %s, icon = %s, label = %s }," %
                     (lua_str(key), lua_str(icon), lua_str(label)))
        o.append("        } },")
    o.append("    },")
    o.append("    graphDays = %d," % GRAPH_DAYS)
    o.append("    size = {")
    for n in sorted(A.meta):
        w, h, _k, ctr = A.meta[n]
        # c says where the clip registers: centred clips are positioned by their
        # middle, the rest by their top-left corner.
        o.append("        [%s] = { w = %.2f, h = %.2f, c = %s },"
                 % (lua_str(n), w, h, "true" if ctr else "false"))
    o.append("    },")
    o.append("}")
    o.append("")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    open(path, "w", encoding="ascii").write("\n".join(o))
    return len(A.meta)


# ---------------------------------------------------------------- preview

# One coherent state for the logistics render. Every figure is derived the way
# mercenaries_logistics.lua derives it, so the screen cannot show an impossible camp:
# 24 men, the food cart feeding 10 of them, 14 left to feed at FeedRatio 8 = 2 units a day,
# 22 units in store = 11 days. Combat is morale*0.5 + smithy 20 + practice level*8.
DEMOLOGI = dict(strength=24, injured=3, wagebill=240, morale=34, combat=61,
                food=22, foodDays=11, drink=9, drinkDays=4, burn=2, coffer=1240, purse=3105,
                history=[26, 25, 23, 24, 22, 20, 17, 15, 12, 16, 21, 24, 23, 22])

DEMOTILES = (7, 12)          # matches the header's TILES 7 / 12
DEMOCAMP = True              # is a camp pitched, for the render
# Nothing caps how many of an improvement you may build, so the list says how many stand.
DEMOCOUNT = {"hunter": 2, "tower": 3, "gate": 2, "circle": 4}

DEMO = {           # key -> status, for the render
    "cart": "built", "inn": "built", "hunter": "owned", "smithy": "built",
    "alchemy": "none", "practice": "none", "house": "built", "circle": "built",
    "tower": "owned", "archercart": "none", "wall": "built", "gate": "owned",
    # The player's own tent is never bought - it stands from the moment the camp does, and
    # the only thing the screen offers for it is Relocate.
    "tent": "built", "stonewall": "none",
}


def preview(A, out, page=1, open_slot=None, scale=1.5, mode="build"):
    W, H = int(STAGE_W * scale), int(STAGE_H * scale)
    bg = Image.new("RGBA", (W, H), (0, 0, 0, 255))
    g = ImageDraw.Draw(bg)
    for y in range(H):
        t = y / float(H)
        if t < 0.60:
            u = t / 0.60
            g.line([(0, y), (W, y)], fill=(int(92 + 66 * u), int(120 + 62 * u), int(160 + 50 * u)))
        else:
            u = (t - 0.60) / 0.40
            g.line([(0, y), (W, y)], fill=(int(92 - 38 * u), int(88 - 34 * u), int(72 - 28 * u)))

    def blit(key, cx, cy, center=True, alpha=1.0, sc=1.0, vmid=False, right=False):
        im = A.art[key]
        w = max(1, int(im.size[0] * scale / SS * sc))
        h = max(1, int(im.size[1] * scale / SS * sc))
        im = im.resize((w, h), Image.HAMMING)
        if alpha < 1.0:
            a = im.getchannel("A").point(lambda v: int(v * alpha))
            im = im.copy(); im.putalpha(a)
        x = cx * scale - (w / 2 if center else (w if right else 0))
        bg.alpha_composite(im, (int(x), int(cy * scale - (h / 2 if center or vmid else 0))))

    def digits(prefix, val, x, y):
        s = str(val)
        for i, ch in enumerate(s):
            blit(prefix + ch, x + i * 8, y)

    # Whatever the detail panel describes is highlighted in the list and ringed on the row,
    # in every state - a panel describing something that nothing points at is a loose end.
    focus = (page - 1) * PAGE + ((open_slot - 2) if open_slot and open_slot > 2 else 1)
    focus = max(1, min(len(IMPROVEMENTS), focus))

    # left panel: the improvement list in build mode, the company's books in logistics mode
    blit("panel", L["hx"] - 8, L["panelY"], center=False)
    blit("title_art", L["hx"], L["hTitleY"], center=False)

    def txt(sx, sy, t, size, col, right=False, face="bold"):
        """The preview composes its own numbers; in game the driver assembles them from the
        digit clips the atlas carries (vd_*/vu_*), the way the header figures already do."""
        im = text_img(t, px(size), col, face=face)
        w = max(1, int(im.size[0] * scale / SS))
        h = max(1, int(im.size[1] * scale / SS))
        im = im.resize((w, h), Image.HAMMING)
        bg.alpha_composite(im, (int(sx * scale) - (w if right else 0),
                                int(sy * scale) - h // 2))

    def ctr(t, size, col, y):
        """Centred in the right panel."""
        w = text_img(t, px(size), col).size[0] / float(SS)
        txt(L["bX"] + L["bW"] / 2.0 - w / 2.0, y, t, size, col)

    def draw_detail():
        """What the focused improvement is, what it costs and what it gives."""
        key, icon, label, field = IMPROVEMENTS[focus - 1]
        st = DEMO.get(key, "none")
        blit("panelD", L["bX"], L["panelY"], center=False)
        txt(L["bX"] + 22, L["bTitleY"] + 8, "IMPROVEMENT", 10, (188, 176, 150))
        # The icon sits beside the name rather than above it: half the height means the
        # portrait layout no longer fits.
        blit("dib_" + icon, L["bX"] + 56, L["panelY"] + 104)
        txt(L["bX"] + 100, L["panelY"] + 92, label, 15, LABEL)
        col, word = {"built": (ST_BUILT, "Built in the camp"),
                     "owned": (ST_OWNED, "Bought, not placed"),
                     "none":  (ST_UNOWNED, "For sale")}[st]
        txt(L["bX"] + 100, L["panelY"] + 116, word, 9, col)
        y = L["panelY"] + 160
        for fld, val in (("cost", "{:,} groschen".format(COST[key]) if key in COST
                                  else "Stands with the camp"),
                         ("effect", BONUS[key][0])):
            blit("dl_" + fld + "_art", L["bX"] + 22, y, center=False, vmid=True)
            txt(L["bX"] + 104, y, val, 10, LABEL if fld != "effect" else (198, 190, 172))
            y += 34

        # how many of this improvement are standing, now that nothing caps them
        y += 14
        txt(L["bX"] + 22, y, "HOW MANY STAND", 10, (188, 176, 150))
        txt(L["bX"] + 100, y + 26, "2 in the camp", 11, LABEL)

    if mode == "logi":
        open_cat = LOGI[open_slot - 2][0] if open_slot and open_slot >= 2 else None
        D = DEMOLOGI
        VAL = {
            "strength": ("%d" % D["strength"], None),
            "injured":  ("%d" % D["injured"], "of %d" % D["strength"]),
            "wagebill": ("{:,}".format(D["wagebill"]), "groschen"),
            "morale":   ("%+d" % D["morale"], "of 100"),
            "combat":   ("%+d%%" % D["combat"], "in a fight"),
            "food":     ("%d" % D["food"], "%d days" % D["foodDays"]),
            "drink":    ("%d" % D["drink"], "%d days" % D["drinkDays"]),
            "burn":     ("%d" % D["burn"], "a day"),
            "coffer":   ("{:,}".format(D["coffer"]), "groschen"),
            "purse":    ("{:,}".format(D["purse"]), "groschen"),
        }
        y = L["statY0"]
        for sect, rows in STATS:
            txt(L["hx"] + 6, y, sect, 9, (176, 166, 146))
            y += L["statSectPitch"]
            touched = LOGI_TOUCHES.get(open_cat, ()) if open_slot else ()
            for key, icon, label in rows:
                if key in touched:
                    blit("statmark", L["hx"] - 2, y - 9, center=False)
                blit("sic_" + icon, L["hx"] + L["statIconDX"], y)
                txt(L["hx"] + L["statNameDX"], y, label, 10, LABEL)
                v, sub = VAL[key]
                txt(L["hx"] + L["statValDX"], y, v, 12, LABEL, right=True)
                if sub:
                    txt(L["hx"] + L["statValDX"] + 6, y, sub, 8, (150, 144, 130))
                # Morale is the one figure that reads both ways, so it gets a bar drawn from
                # the middle out - a number alone does not say how close to mutiny that is.
                if key == "morale":
                    bx = L["hx"] + L["statNameDX"]
                    by = y + 13
                    blit("mbar_bg", bx, by, center=False)
                    half = L["moraleBarW"] / 2.0
                    frac = max(-1.0, min(1.0, D["morale"] / 100.0))
                    col = "good" if D["morale"] >= 0 else ("warn" if D["morale"] > -50 else "bad")
                    run = abs(frac) * half                       # stage units, from the middle
                    x0 = bx + half + (0 if frac >= 0 else -run)
                    im = A.art["mbar_" + col]
                    im = im.resize((max(1, int(run * scale)),
                                    max(1, int(im.size[1] * scale / SS))), Image.HAMMING)
                    bg.alpha_composite(im, (int(x0 * scale), int(by * scale)))
                    blit("mbar_mid", bx + half, by - 2, center=False)
                    y += 14
                y += L["statPitch"]
            y += 6

        # ---- right panel: what the upgrades are doing, and the supply line
        blit("panelB", L["bX"], L["panelY"], center=False)
        txt(L["bX"] + 22, L["bTitleY"] + 8, "ACTIVE UPGRADES", 10, (188, 176, 150))
        by = L["bListY0"]
        built_total = sum(1 for k, _i, _l, _c in IMPROVEMENTS if DEMO.get(k) == "built")
        shown, cap = 0, bonus_rows(built_total)
        for key, icon, label, _c in IMPROVEMENTS:
            if DEMO.get(key) != "built":
                continue
            if shown >= cap:
                break
            shown += 1
            blit("ic_" + icon, L["bX"] + L["bIconDX"], by + 6)
            txt(L["bX"] + L["bNameDX"], by, label, 11, LABEL)
            txt(L["bX"] + L["bNameDX"], by + L["bBonusDY"], BONUS[key][0], 9, (168, 160, 144))
            unit = BONUS[key][1]
            if unit == "days":
                txt(L["bX"] + L["bW"] - 22, by + 6, "%d d" % (9 if key == "cart" else 2),
                    11, RING_GOLD, right=True)
            elif unit == "pct":
                txt(L["bX"] + L["bW"] - 22, by + 6, "+24%", 11, RING_GOLD, right=True)
            by += L["bPitch"]
        left_out = built_total - shown
        if left_out > 0:
            txt(L["bX"] + 22, by + 6, "+%d more, not shown" % left_out, 9, (150, 144, 130))

        txt(L["bX"] + 22, L["graphY"] - 14, "FOOD, LAST %d DAYS" % GRAPH_DAYS, 10,
            (188, 176, 150))
        gx = L["bX"] + L["graphDX"]
        gy = L["graphY"] + L["graphH"]
        hist = D["history"]
        top = max(max(hist), 1)
        for i in range(1, 4):
            blit("ggrid", gx, gy - L["graphH"] * i / 3.0, center=False)
        for i, v in enumerate(hist):
            bh = max(1, L["graphH"] * v / float(top))
            bx = gx + (i + 0.5) * (L["graphW"] / float(GRAPH_DAYS))
            im = A.art["gbar_low" if v <= D["burn"] * 3 else "gbar"]
            w = max(1, int(im.size[0] * scale / SS))
            im = im.resize((w, max(1, int(bh * scale))), Image.HAMMING)
            bg.alpha_composite(im, (int(bx * scale) - w // 2, int((gy - bh) * scale)))
        blit("gbase", gx, gy, center=False)
        txt(gx, gy + L["graphLabelDY"], "%d days ago" % GRAPH_DAYS, 8, (140, 134, 122))
        txt(gx + L["graphW"], gy + L["graphLabelDY"], "today", 8, (140, 134, 122), right=True)
    else:
        # Right-aligned to the same column the logistics figures use, so a number sits in
        # the same place whichever mode you are in.
        blit("lbl_tiles_art", L["hx"], L["hStatY"] + 9, center=False, vmid=True)
        txt(L["hx"] + L["statValDX"], L["hStatY"] + 9, "7 / 12", 13, LABEL, right=True)
        blit("lbl_purse_art", L["hx"], L["hStat2Y"] + 9, center=False, vmid=True)
        txt(L["hx"] + L["statValDX"], L["hStat2Y"] + 9, "3,105", 13, LABEL, right=True)
        blit("lbl_camp_art", L["hx"], L["hCampY"] + 9, center=False, vmid=True)
        txt(L["hx"] + L["statValDX"], L["hCampY"] + 9,
            "Pitched" if DEMOCAMP else "None", 13,
            ST_BUILT if DEMOCAMP else ST_UNOWNED, right=True)
        blit("lbl_improv_art", L["hx"] + 6, L["listY0"] - 20, center=False)
        draw_detail()

        for i, (key, icon, label, _c) in enumerate(IMPROVEMENTS, 1):
            y = L["listY0"] + (i - 1) * L["listPitch"]
            st = DEMO.get(key, "none")
            if focus == i:
                blit("rowsel", L["hx"] - 6, y - 3, center=False)
            mid = y - 2 + (L["listPitch"] - 4) / 2.0
            blit("ic_" + icon, L["hx"] + L["listIconDX"], mid,
                 alpha=1.0 if st != "none" else 0.45)
            blit("nm_" + label, L["hx"] + L["listNameDX"], mid, center=False, vmid=True,
                 alpha=1.0 if st != "none" else 0.55)
            blit("pill_" + st, L["hx"] + L["listPillDX"], mid, center=False, vmid=True)
            n = DEMOCOUNT.get(key)
            if n:
                txt(L["hx"] + L["listCountDX"], mid, "x%d" % n, 9, (176, 166, 146), right=True)

    # bottom row. Slot 1 is always the mode toggle, so the key that changes mode never
    # moves; the rest of the row belongs to whichever mode is up.
    slots = [dict(icon="ic_tab_build" if mode == "logi" else "ic_tab_logistics",
                  label="lblb_Build" if mode == "logi" else "lblb_Logistics", mode=True)]
    if mode == "logi":
        for key, icon, label in LOGI:
            slots.append(dict(icon="icb_" + icon, label="lblb_" + label, cat=key))
    else:
        slots.append(dict(icon="icb_camp_tent", label="lblb_Camp", camp=True))
        pages = (len(IMPROVEMENTS) + PAGE - 1) // PAGE
        for i in range(PAGE):
            idx = (page - 1) * PAGE + i + 1
            if idx > len(IMPROVEMENTS):
                break
            key, icon, label, _c = IMPROVEMENTS[idx - 1]
            slots.append(dict(icon="icb_" + icon, label="lblb_" + label,
                              status=DEMO.get(key, "none"), cat=key,
                              note=ROW_NOTE.get(key)))
        slots.append(dict(icon="ic_more", more=True,
                          label="lbl_More_%d_%d" % (page, pages)))

    n = len(slots)
    x0 = STAGE_W / 2.0 - (n - 1) * L["btnPitch"] / 2.0
    for slot, d in enumerate(slots, 1):
        cx, cy = x0 + (slot - 1) * L["btnPitch"], L["rowY"]
        sc = L["btnOpenScale"] if slot == open_slot else 1.0
        lit = slot == open_slot or (mode != "logi" and not open_slot
                                    and d.get("cat") == IMPROVEMENTS[focus - 1][0])
        blit("disc_on" if lit else "disc_plain", cx, cy, sc=sc)
        # Unbought improvements dim on the row exactly as they do in the list, so the two
        # halves of the screen tell the same story without being read together.
        dim = 0.55 if d.get("status") == "none" else 1.0
        blit(d["icon"], cx, cy, sc=sc, alpha=dim)
        blit(d["label"], cx, cy + L["btnLabelDY"], alpha=dim)
        if d.get("note"):
            txt(cx, cy + L["btnLabelDY"] + 13, d["note"], 7, (214, 168, 78))
        if not open_slot:
            blit("chip", cx, cy + L["btnBadgeDY"])
            blit("key_" + ROWKEYS[slot - 1], cx, cy + L["btnBadgeDY"])

    # wheel
    if open_slot:
        d0 = slots[open_slot - 1]
        if d0.get("camp"):
            items = CAMP_WHEEL_ON if DEMOCAMP else CAMP_WHEEL_OFF
        elif mode == "logi":
            items = LOGI_WHEELS[d0.get("cat")]
        else:
            items = ACTIONS
        cx0 = x0 + (open_slot - 1) * L["btnPitch"]
        cy0 = L["rowY"] + L["wheelDY"]
        cnt = len(items)
        for j, (key, icon, label) in enumerate(items):
            ang = -math.pi / 2 + 2 * math.pi * j / cnt
            cx = cx0 + math.cos(ang) * L["wheelR"]
            cy = cy0 + math.sin(ang) * L["wheelR"]
            # An action that cannot apply right now is dimmed rather than hidden, so the
            # wheel keeps the same shape and the same keys whatever the camp's state.
            # No default ring: the gold ring means "the button you have open", and using it
            # again for a suggested action reads as two selections at once.
            off = (mode != "logi" and key in ("buy", "build"))
            a = 0.62 if off else 1.0
            # The disc stays fully opaque even when disabled, so a dimmed action still has a
            # dark backing and does not vanish against bright sky.
            blit("wdisc_plain", cx, cy)
            blit("icw_" + icon, cx, cy, alpha=a)
            # The plate keeps its own opacity whatever the state: dimming it thins it, and a
            # thin plate over bright sky is LIGHTER than an opaque one, which inverted the
            # whole point of dimming.
            blit("lblw_" + label + ("_off" if off else ""), cx, cy + L["wheelLabelDY"])
            # The badge never dims: it says which key this is, which is true whether or
            # not the action can be taken, and a dimmed chip vanishes against bright sky.
            blit("chip", cx, cy + L["wheelBadgeDY"])
            kn = CAMP_KEY[1] if key == "return" else WHEELKEYS[j]
            blit("key_" + kn, cx, cy + L["wheelBadgeDY"])

    # corner hint
    cw = A.art["chip"].size[0] / float(SS)
    if open_slot:
        # the wheel's Return spoke already carries U; saying it twice labels one key
        # with two different words
        os.makedirs(os.path.dirname(out), exist_ok=True)
        bg.convert("RGB").save(out, quality=94)
        return out
    hl = "hint_lbl_art"
    lw = A.art[hl].size[0] / float(SS)
    hx = L["hintCompassX"]                          # the Close prompt's own spot
    bw = A.art["hbtn_" + CAMP_KEY[1]].size[0] / float(SS)
    hy = L["hintTopY"]
    blit("hbtn_" + CAMP_KEY[1], hx - bw / 2, hy)
    blit(hl, hx - bw - L["hintGap"] - lw / 2, hy)

    os.makedirs(os.path.dirname(out), exist_ok=True)
    bg.convert("RGB").save(out, quality=94)
    return out


if __name__ == "__main__":
    A = build()
    swf = A.write(os.path.join(ROOT, "data", "libs", "UI", "MercCamp.swf"),
                  os.path.join(ROOT, "data", "libs", "UI", "UIElements", "MercCamp.xml"),
                  "MercCamp")
    n = write_lua(os.path.join(ROOT, "data", "Scripts", "mods", "mercenaries_campatlas.lua"), A)
    print("MercCamp.swf  %.1f KB, %d clips, %d unique images"
          % (len(swf) / 1024.0, len(A.names), len(A.shapes)))
    print("campatlas.lua %d clip sizes" % n)
    if "--preview" in sys.argv:
        for nm, kw in (("idle", {}), ("wheel", {"open_slot": 3}), ("page2", {"page": 2}),
                       ("logi", {"mode": "logi"}),
                       ("logi_wheel", {"mode": "logi", "open_slot": 2})):
            p = preview(A, os.path.join(ROOT, "tools", "out", "camp_%s.png" % nm), **kw)
            print("preview ->", p)
