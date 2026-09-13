"""Offline renderer for the battle command interface (docs/ui.md).

The in-game UI is drawn only with System.DrawText, a fixed-width debug font. That makes it
cheap to emulate: one call is one monospace string at a known pixel size and colour. This
mirrors mercenaries_cmdui.lua's CmdDraw exactly, so layout numbers tuned here port straight
back into CMD.L without a game launch.

MEASURED against a real 3840x2160 screenshot:
  advance width = 8.08 px per DrawText size unit   (charW 4.04 per S, S = height/1080)
  cap height    = 9.0  px per size unit
  DrawText's y is the TOP of the text box.

  python tools/uimock.py out.png            render with the current defaults
  python tools/uimock.py out.png key=value  override any layout number
"""
import sys, os
from PIL import Image, ImageDraw, ImageFont

W, H = 3840, 2160
S = H / 1080.0
ADV_PER_SIZE = 8.08          # px of advance per size unit at 3840x2160
CAP_PER_SIZE = 9.0
FONT = r"C:\Windows\Fonts\consola.ttf"
BACKDROP = None              # set by --bg

GOLD = (230, 194, 92)
DIM  = (186, 181, 168)
GREY = (199, 199, 194)
CREAM  = (238, 232, 214)     # on a lit panel the text goes bright, not gold
CATDIM = (196, 192, 182)     # category strip sits a notch above the order strip
KEYDIM = (150, 128, 74)      # muted gold: a hotkey is not a selection

L = dict(
    BW=1500, gapx=16, botY=320,
    cardH=96, catH=54, ordH=58, headH=84,
    gapCat=26, gapOrd=26, gapTitle=40, gapHint=26,
    padx=20, nameY=40, countY=16, idxY=16,
    hintX=22, headTitleY=10, headHintY=52, catTextY=14, ordTextY=16,
    sName=4.4, sCat=4.0, sOrdKey=3.5, sOrd=3.2, sTitle=5.2, sHint=4.0, sLast=5.5,
    sHero=4.8, sBar=3.4, sSum=4.4, barY=76,
    charW=4.04,
)

GROUPS = [("Infantry I", 8, 10), ("Infantry II", 8, 8), ("Infantry III", 6, 10),
          ("Archers I", 5, 6), ("Archers II", 4, 6)]
CATS = [("Movement", ["Charge", "Advance", "Fall Back", "Stand Ground", "Follow Me", "Retreat"]),
        ("Formation", ["Line", "Shield Wall", "Loose", "Circle", "Skein", "Column", "Square"]),
        ("Mount", ["Mount", "Dismount"]),
        ("Position", None)]
KEYS = ["F2", "F3", "F4", "F6", "F7", "F8", "F11"]
OPEN_CAT = 0            # which category is open, or None
SELECTED = {0: True}

_fontcache = {}
def font_for(size):
    px = max(6, int(round(size * ADV_PER_SIZE / 0.55)))   # consolas advance = 0.55 em
    if px not in _fontcache:
        _fontcache[px] = ImageFont.truetype(FONT, px)
    return _fontcache[px]

def adv(size):
    return size * ADV_PER_SIZE

BEAR = 0.30      # px of ascent above the cap, per size unit; keeps y = visual cap top
def text(d, x, y, s, size, col, alpha=255):
    f = font_for(size)
    d.text((x, y - size * BEAR * ADV_PER_SIZE / 2.0), str(s), font=f, fill=col + (alpha,))

def text_w(s, size):
    return len(str(s)) * adv(size)

def fill(d, x, y, w, h, col, alpha):
    d.rectangle([x, y, x + w, y + h], fill=col + (alpha,))

def rule(d, x, y, w, col, alpha=255):
    d.rectangle([x, y - 2, x + w, y + 2], fill=col + (alpha,))

def panel(d, x, y, w, h, sel, norule_bottom=False):
    if sel:
        fill(d, x, y, w, h, (100, 80, 35), 248)
        d.rectangle([x, y - 5, x + w, y + 5], fill=GOLD + (255,))   # the one selection cue
        rule(d, x, y + h, w, (107, 99, 87), 230)
    else:
        fill(d, x, y, w, h, (26, 25, 28), 238)
        rule(d, x, y, w, (107, 99, 87), 230)
        if not norule_bottom:
            rule(d, x, y + h, w, (107, 99, 87), 230)

def pair(d, x, y, w, key, name, size, tc, keycol=None):
    keycol = keycol or GOLD
    gap = 2 if key else 0
    chars = len(key) + gap + len(name)
    avail = w - 16 * S
    if chars * adv(size) > avail:
        size = avail / (chars * ADV_PER_SIZE)
    tw = chars * adv(size)
    cx = x + (w - tw) * 0.5
    if key:
        text(d, cx, y, key, size, keycol)
    text(d, cx + (len(key) + gap) * adv(size), y, name, size, tc)

def render(path):
    if BACKDROP and os.path.exists(BACKDROP):
        bg = Image.open(BACKDROP).convert("RGB").resize((W, H))
        # use a clean strip of sky/ground, stretched, so no old UI bleeds in
        bg = bg.crop((0, 0, W, int(H * 0.42))).resize((W, H))
    else:
        bg = Image.new("RGB", (W, H), (38, 40, 34))
    base = bg.convert("RGBA")
    ov = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(ov)

    BW = L["BW"] * S
    left = (W - BW) * 0.5
    gapx = L["gapx"] * S
    cardH, catH, ordH = L["cardH"] * S, L["catH"] * S, L["ordH"] * S
    cardY = H - L["botY"] * S
    catY = cardY - catH - L["gapCat"] * S
    ordY = catY - ordH - L["gapOrd"] * S
    titleY = ordY - L["gapTitle"] * S
    cw_ch = L["charW"] * S

    headH_ = L["headH"] * S
    headY_ = (titleY if OPEN_CAT is not None else catY) - L["gapHint"] * S - headH_
    bx0, by0 = left - 28 * S, headY_ - 24 * S
    bx1, by1 = left + BW + 28 * S, cardY + cardH + 24 * S
    d.rectangle([bx0, by0, bx1, by1], fill=(6, 6, 8, 150))
    d.rectangle([bx0, by0, bx1, by1], outline=(112, 108, 99, 255), width=3)

    # block scrim, drawn first so every row sits on one continuous ground
    scrimTop = None
    n = len(GROUPS)
    cw = (BW - (n - 1) * gapx) / n
    for i, (name, men, cap) in enumerate(GROUPS):
        x = left + i * (cw + gapx)
        sel = SELECTED.get(i, False)
        panel(d, x, cardY, cw, cardH, sel)
        tc = CREAM if sel else DIM
        text(d, x + L["padx"] * S, cardY + L["idxY"] * S, i + 1, L["sName"],
             CREAM if sel else GREY)
        cnt = "%d men" % men
        text(d, x + cw - L["padx"] * S - text_w(cnt, L["sName"]),
             cardY + L["countY"] * S, cnt, L["sName"], GREY)
        nw = text_w(name, L["sHero"])
        text(d, x + (cw - nw) * 0.5, cardY + L["nameY"] * S, name, L["sHero"], tc)
        # filled = men present, dots = losses against the squad's full complement
        bar, lost = "|" * men, "x" * max(0, cap - men)
        bw_ = text_w(bar + lost, L["sBar"])
        bx = x + (cw - bw_) * 0.5
        text(d, bx, cardY + L["barY"] * S, bar, L["sBar"],
             CREAM if sel else DIM, 255)
        text(d, bx + text_w(bar, L["sBar"]), cardY + L["barY"] * S, lost, L["sBar"],
             (219, 74, 48), 255)

    # categories
    nk = len(CATS)
    bw = (BW - (nk - 1) * gapx) / nk
    for i, (nm, _o) in enumerate(CATS):
        x = left + i * (bw + gapx)
        act = (OPEN_CAT == i)
        panel(d, x, catY, bw, catH, act)
        k = "" if OPEN_CAT is not None else KEYS[i]
        pair(d, x, catY + L["catTextY"] * S, bw, k, nm, L["sCat"],
             CREAM if act else CATDIM, CREAM if act else KEYDIM)

    # orders
    if OPEN_CAT is not None and CATS[OPEN_CAT][1]:
        orders = CATS[OPEN_CAT][1]
        no = len(orders)
        ow = (BW - (no - 1) * gapx) / no
        for i, o in enumerate(orders):
            x = left + i * (ow + gapx)
            panel(d, x, ordY, ow, ordH, False)
            pair(d, x, ordY + L["ordTextY"] * S, ow, KEYS[i], o, L["sOrd"], DIM, KEYDIM)

    # header band
    headH = L["headH"] * S
    headY = (titleY if OPEN_CAT is not None else catY) - L["gapHint"] * S - headH
    panel(d, left, headY, BW, headH, False, norule_bottom=True)
    title = (CATS[OPEN_CAT][0].upper() + " ORDERS") if OPEN_CAT is not None else "COMPANY"
    text(d, left + L["padx"] * S, headY + L["headTitleY"] * S, title, L["sTitle"], GOLD)
    keyrange = "F2-F4, F6-F8" if OPEN_CAT is not None else "F2-F4, F6"
    what = "order" if OPEN_CAT is not None else "category"
    hint = "%s %s  |  numpad 1-%d select, 0 all" % (keyrange, what, len(GROUPS))
    text(d, left + L["hintX"] * S, headY + L["headHintY"] * S, hint, L["sHint"], DIM)
    dismiss = "F9 back" if OPEN_CAT is not None else "F9 hide"
    text(d, left + BW - 8 * S - text_w(dismiss, L["sHint"]),
         headY + L["headHintY"] * S, dismiss, L["sHint"], (140, 136, 126))
    sel_i = [i for i in range(len(GROUPS)) if SELECTED.get(i, False)]
    nmen = sum(GROUPS[i][1] for i in sel_i)
    if len(sel_i) == 1:
        summ = "%s  |  %d men" % (GROUPS[sel_i[0]][0], nmen)
    elif sel_i:
        summ = "%d squads  |  %d men" % (len(sel_i), nmen)
    else:
        summ = "nothing selected"
    text(d, left + BW - 8 * S - text_w(summ, L["sSum"]),
         headY + L["headTitleY"] * S, summ, L["sSum"], GOLD)

    Image.alpha_composite(base, ov).convert("RGB").save(path, quality=92)
    print("wrote", path)

if __name__ == "__main__":
    out = sys.argv[1]
    for a in sys.argv[2:]:
        if a.startswith("--bg="):
            BACKDROP = a[5:]
        elif "=" in a:
            k, v = a.split("=", 1)
            if k == "opencat":
                OPEN_CAT = None if v == "none" else int(v)
            else:
                L[k] = float(v)
    render(out)
