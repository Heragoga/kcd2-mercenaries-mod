"""Check that every clip mercenaries_blui.lua can ask for exists in the generated atlas.

The driver builds clip names by string concatenation, so a rename in tools/make_bl.py shows
up in game as a silently missing icon rather than an error. This walks every state the
interface can be in and asserts the name is declared.

    python tools/check_blui.py
"""
import os, re, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_bl as B

ROOT = B.ROOT
LUA = os.path.join(ROOT, "data", "Scripts", "mods", "mercenaries_blatlas.lua")
XML = os.path.join(ROOT, "data", "libs", "UI", "UIElements", "MercBL.xml")


def declared():
    names = set(re.findall(r'\[\"([^\"]+)\"\] = \{ w =', open(LUA, encoding="ascii").read()))
    xml = set(re.findall(r'instancename="([^"]+)"', open(XML, encoding="ascii").read()))
    return names, xml


def wanted():
    """Every name the driver can form, over every reachable state."""
    out = set()
    out.add("vig")
    out |= {"hint_lbl", "hint_lbl_close"}
    # The prompt button art is per key: the driver only ever draws the hide key, but the
    # atlas carries the whole pool so a rebind needs no new art.
    out |= {"hint_btn_" + name for _k, name in B.BIND}
    out.add("hint_btn_" + B.HIDE_KEY[1])

    for i in range(1, 6):
        p = "c%d_" % i
        out |= {p + "plate", p + "sel", p + "hpbg", p + "chip", p + "num"}
        out |= {p + "hp_" + b for b in "gar"}
        out.add(p + "hp_dead")
        for t in B.TROOP_TYPES:
            out.add(p + "wm_" + t)
            out.add(p + "ty_" + t)
        for d in range(10):
            out.add(p + "d0_%d" % d)
            out.add(p + "d1_%d" % d)
        for k, _ic in B.CARD_STATES:
            out.add(p + "o_" + k)

    for i, (slot, src, _t) in enumerate(B.BOTTOM, 1):
        p = "b%d_" % i
        out |= {p + "disc", p + "ring", p + "chip"}
        for _k, name in B.BIND:
            out.add(p + "k_" + name)
        for k, _ic, _lb in B.bottom_variants(slot, src):
            out.add(p + "i_" + k)
            out.add(p + "t_" + k)

    slots = max([len(v) for v in B.SIMPLE_WHEELS.values()]
                + [len(v) for v in B.STATE_WHEELS.values()])
    for j in range(1, slots + 1):
        p = "w%d_" % j
        out |= {p + "disc", p + "ring", p + "chip"}
        for _k, name in B.BIND:
            out.add(p + "k_" + name)
        for cat, items in B.SIMPLE_WHEELS.items():
            if j <= len(items):
                k = items[j - 1][0]
                out.add(p + "i_%s_%s" % (cat, k))
                out.add(p + "t_%s_%s" % (cat, k))
        for cat, ent in B.STATE_WHEELS.items():
            if j <= len(ent):
                slot, states = ent[j - 1]
                for k, _ic, _lb in states:
                    out.add(p + "i_%s_%s_%s" % (cat, slot, k))
                    out.add(p + "t_%s_%s_%s" % (cat, slot, k))
    return out


def lua_scope_check():
    """A Lua local referenced above its own declaration resolves to a nil global and the call
    silently does nothing - no error, no log line. That has bitten this file three times, so
    it is checked rather than remembered."""
    src = os.path.join(ROOT, "data", "Scripts", "mods", "mercenaries_blui.lua")
    lines = open(src, encoding="utf-8").read().splitlines()
    decl = {}
    for i, l in enumerate(lines):
        m = re.match(r"\s*local\s+(?:function\s+)?([A-Za-z_]\w*)((?:\s*,\s*[A-Za-z_]\w*)*)", l)
        if m:
            for n in [m.group(1)] + re.findall(r"[A-Za-z_]\w*", m.group(2) or ""):
                decl.setdefault(n, i)
    bad = []
    for name, dl in decl.items():
        if len(name) < 4:
            continue
        for i in range(0, dl):
            if re.search(r"(?<![\w.:])%s\s*\(" % re.escape(name), lines[i]):
                bad.append((name, i + 1, dl + 1))
                break
    for n, u, d in bad:
        print("USE BEFORE DECLARATION: %s used at line %d, declared at %d" % (n, u, d))
    return not bad


def handler_check():
    """Every mercenaries:BLxxx the driver dispatches to must actually be defined somewhere.

    The driver calls them behind `if mercenaries.BLFoo then ... end` guards, so a handler that
    is deleted - by a bad edit, a merge, a file that failed to load - does not error. The
    button simply stops doing anything, which looks like a behaviour bug and is not one. This
    has happened twice.
    """
    mods = os.path.join(ROOT, "data", "Scripts", "mods")
    called, defined = set(), set()
    for fn in os.listdir(mods):
        if not fn.endswith(".lua"):
            continue
        src = open(os.path.join(mods, fn), encoding="utf-8", errors="replace").read()
        defined |= set(re.findall(r"function\s+mercenaries:(BL\w+)", src))
        if fn == "mercenaries_blui.lua":
            called |= set(re.findall(r"mercenaries[:.](BL\w+)\s*\(", src))
            called |= set(re.findall(r"if\s+mercenaries\.(BL\w+)\s+then", src))
    # names the driver defines on itself are fine too
    src = open(os.path.join(mods, "mercenaries_blui.lua"), encoding="utf-8", errors="replace").read()
    defined |= set(re.findall(r"mercenaries\.(BL\w+)\s*=", src))
    missing = sorted(n for n in called if n not in defined)
    for n in missing:
        print("DISPATCHED BUT NEVER DEFINED: mercenaries:%s" % n)
    return not missing


def command_check():
    """Commands the interface binds keys to must exist WITHOUT merc_dev.

    DevCommand only collects; the console does not learn the name until merc_dev is typed. A
    key bound to a command the console does not know does nothing at all, with no error - so
    the whole interface silently fails for anyone who has not run merc_dev.
    """
    mods = os.path.join(ROOT, "data", "Scripts", "mods")
    dev, player = set(), set()
    for fn in os.listdir(mods):
        if not fn.endswith(".lua"):
            continue
        src = open(os.path.join(mods, fn), encoding="utf-8", errors="replace").read()
        dev |= set(re.findall(r'DevCommand\("([\w]+)"', src))
        player |= set(re.findall(r'PlayerCommand\("([\w]+)"', src))
        # loop-registered families, e.g. "merc_bl_k" .. i
        player |= set(re.findall(r'PlayerCommand\("([\w]+)"\s*\.\.', src))
    bound = {"merc_bl", "merc_bl_esc", "merc_bl_place"}
    bound |= {"merc_bl_k"} | {"merc_bl_sel"}
    bad = sorted(n for n in bound if n not in player)
    for n in bad:
        print("BOUND TO A KEY BUT NOT A PlayerCommand: %s (needs merc_dev to exist)" % n)
    return not bad


def toggle_check():
    """Every slot in the Toggle wheel must have a branch in BLToggleApply.

    The wheel is data and the handler is code, so adding a toggle to tools/make_bl.py without
    wiring it leaves a button that cycles its own icon and changes nothing in the game.
    """
    src = open(os.path.join(ROOT, "data", "Scripts", "mods", "mercenaries_blorders.lua"),
               encoding="utf-8", errors="replace").read()
    i = src.find("function mercenaries:BLToggleApply")
    body = src[i:src.find(chr(10) + "end", i)] if i >= 0 else ""
    handled = set(re.findall(r'slot\s*==\s*"(\w+)"', body))
    slots = {slot for slot, _st in B.STATE_WHEELS["tog"] if slot != "return"}
    missing = sorted(slots - handled)
    for n in missing:
        print("TOGGLE SLOT NOT HANDLED BY BLToggleApply: %s" % n)
    return not missing


def main():
    have, xml = declared()
    want = wanted()
    missing = sorted(want - have)
    not_in_xml = sorted(want - xml)
    unused = sorted(have - want)

    print("atlas declares %d clips, driver can request %d" % (len(have), len(want)))
    if missing:
        print("MISSING from the atlas (%d):" % len(missing))
        for n in missing[:40]:
            print("   ", n)
    if not_in_xml:
        print("MISSING from MercBL.xml (%d):" % len(not_in_xml))
        for n in not_in_xml[:40]:
            print("   ", n)
    if unused:
        print("declared but unreachable (%d) - harmless, but dead weight:" % len(unused))
        for n in unused[:20]:
            print("   ", n)

    # The wheel only ever has as many slots as the longest category.
    longest = max([len(v) for v in B.SIMPLE_WHEELS.values()] + [len(v) for v in B.STATE_WHEELS.values()])
    print("longest wheel: %d items; order keys available: %d" % (longest, B.RETURN_SLOT - 1))
    # Return must be reachable: its key index must not collide with a real order's.
    for nm, items in (("move", B.MOVE), ("form", B.FORM),
                      ("toggle", [(s, None, None) for s, _ in B.TOGGLE])):
        n = len(items)
        if n > B.RETURN_SLOT:
            print("BAD: %s wheel has %d items but Return is pinned to key %d"
                  % (nm, n, B.RETURN_SLOT))
    scope_ok = lua_scope_check()
    handlers_ok = handler_check()
    cmds_ok = command_check()
    tog_ok = toggle_check()
    ok = not missing and not not_in_xml and scope_ok and handlers_ok and cmds_ok and tog_ok
    print("PASS" if ok else "FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
