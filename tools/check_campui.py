"""Check that every clip mercenaries_campui.lua can ask for exists in the camp atlas.

The driver builds clip names by string concatenation, so a rename in tools/make_camp.py
shows up in game as a silently missing icon rather than an error. This walks every state the
screen can be in and asserts the name is declared.

    python tools/check_campui.py
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_camp as C
import make_bl as B

ROOT = C.ROOT
LUA = os.path.join(ROOT, "data", "Scripts", "mods", "mercenaries_campatlas.lua")
DRV = os.path.join(ROOT, "data", "Scripts", "mods", "mercenaries_campui.lua")
XML = os.path.join(ROOT, "data", "libs", "UI", "UIElements", "MercCamp.xml")


def declared():
    names = set(re.findall(r'\[\"([^\"]+)\"\] = \{ w =', open(LUA, encoding="ascii").read()))
    xml = set(re.findall(r'instancename="([^"]+)"', open(XML, encoding="ascii").read()))
    return names, xml


def wanted():
    """Every INSTANCE name the driver can form, over every reachable state.

    Instance names, not image names: several instances share one image and it is the
    instance that can be moved, so those are what the driver addresses.
    """
    out = {"panel", "panelB", "title", "statmark",
           "hint_lbl", "hint_lbl_open", "hint_lbl_back",
           "lbl_purse", "lbl_camp", "lbl_improv",
           "lbl_detail", "lbl_bonuses", "lbl_graph",
           "lbl_groschen", "lbl_free", "lbl_onetile", "lbl_ago", "lbl_today",
           "dl_cost", "dl_effect", "lbl_standing", "lbl_inthecamp",
           "camp_yes", "camp_no",
           "camp_ic", "camp_lbl", "tab_to_build", "tab_to_logi",
           "tab_lbl_build", "tab_lbl_logi",
           "mbar_bg", "mbar_mid", "gbase", "ggrid"}

    for st in C.STATUSES:
        out.add("dst_" + st)
    for c in ("good", "warn", "bad"):
        out.add("mbar_" + c)
    for field in C.numfields():
        for pos in range(1, C.NUMPOS + 1):
            for g, _t in C.GLYPHS:
                out.add("n_%s_%d_%s" % (field, pos, g))
    for k in B.KEY_POOL:
        # the letter is baked into the cap, so there is no separate hint_k_ instance
        out.add("hint_btn_" + k)

    # the improvement list
    for i, (key, _ic, label, _c) in enumerate(C.IMPROVEMENTS, 1):
        p = "r%d_" % i
        out |= {p + "sel", p + "ic", p + "nm"}
        for st in C.STATUSES:
            out.add(p + "pill_" + st)
        # detail panel and the upgrades panel address by key
        out |= {"d_%s_ic" % key, "d_%s_nm" % key,
                "u_%s_ic" % key, "u_%s_nm" % key, "u_%s_bo" % key}

    # build row: mode, camp, PAGE improvements, More
    pages = (len(C.IMPROVEMENTS) + C.PAGE - 1) // C.PAGE
    for slot in range(1, 2 + C.PAGE + 2):
        p = "b%d_" % slot
        out |= {p + "disc", p + "ring", p + "chip"}
        for k in B.KEY_POOL:
            out.add(p + "k_" + k)
        for key, _ic, _lb, _c in C.IMPROVEMENTS:
            out |= {p + "i_" + key, p + "t_" + key}
        out.add(p + "i_more")
        for pg in range(1, pages + 1):
            out.add(p + "t_more_%d" % pg)

    # logistics row
    for slot in range(1, len(C.LOGI) + 2):
        p = "lb%d_" % slot
        out |= {p + "disc", p + "ring", p + "chip"}
        for k in B.KEY_POOL:
            out.add(p + "k_" + k)
        for key, _ic, _lb in C.LOGI:
            out |= {p + "i_" + key, p + "t_" + key}

    # stats
    for sect, rows in C.STATS:
        out.add("sect_" + sect.replace(" ", "_"))
        for key, _ic, _lb in rows:
            out |= {"s_%s_ic" % key, "s_%s_nm" % key}

    # wheels
    for pre, wheels in (("w", [C.ACTIONS]),
                        ("cw", [C.CAMP_WHEEL_ON, C.CAMP_WHEEL_OFF])):
        n = max(len(w) for w in wheels)
        for j in range(1, n + 1):
            p = "%s%d_" % (pre, j)
            out |= {p + "disc", p + "chip"}
            for k in B.KEY_POOL:
                out.add(p + "k_" + k)
            # spoke j only ever holds item j of a wheel
            for w in wheels:
                if j <= len(w):
                    key = w[j - 1][0]
                    out |= {p + "i_" + key, p + "t_" + key}
                    if pre == "w":
                        out.add(p + "t_" + key + "_off")
    n = max(len(v) for v in C.LOGI_WHEELS.values())
    for j in range(1, n + 1):
        p = "lw%d_" % j
        out |= {p + "disc", p + "chip"}
        for k in B.KEY_POOL:
            out.add(p + "k_" + k)
        for cat, items in C.LOGI_WHEELS.items():
            if j <= len(items):
                key = items[j - 1][0]
                out |= {"%si_%s_%s" % (p, cat, key), "%st_%s_%s" % (p, cat, key)}

    # the graph
    for i in range(1, C.GRAPH_DAYS + 1):
        out |= {"g%d" % i, "g%d_low" % i}

    return out


def lua_scope_check():
    """A Lua local referenced above its own declaration resolves to a nil global and the
    call silently does nothing - no error, no log line."""
    lines = open(DRV, encoding="utf-8").read().splitlines()
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
    """Every mod function the driver calls must actually exist somewhere in the mod.

    The driver reaches into the logistics and camp modules by name through pcall, so a
    renamed function does not error - the button simply stops doing anything.
    """
    mods = os.path.join(ROOT, "data", "Scripts", "mods")
    defined = set()
    for fn in os.listdir(mods):
        if fn.endswith(".lua"):
            src = open(os.path.join(mods, fn), encoding="utf-8", errors="replace").read()
            defined |= set(re.findall(r"function\s+mercenaries[:.](\w+)", src))
            defined |= set(re.findall(r"mercenaries\.(\w+)\s*=\s*function", src))
    src = open(DRV, encoding="utf-8", errors="replace").read()
    called = set(re.findall(r'"(Logi\w+|Spawn\w+|Break\w+|Camp\w+|Gate\w+|Wall\w+)"', src))
    called |= set(re.findall(r"self:(Logi\w+|Spawn\w+|Break\w+|Camp\w+|Tower\w+|Start\w+|"
                             r"End\w+|Recount|GetSafeSpawnPosition|SaveString|LoadString)"
                             r"\s*\(", src))
    # ...and calls written against the global table rather than self, which sit inside
    # pcalls and so fail completely silently (WallPieceCount never existed).
    called |= set(re.findall(r"mercenaries:(\w+)\s*\(", src))

    missing = sorted(n for n in called if n not in defined)
    for n in missing:
        print("DRIVER CALLS A FUNCTION THE MOD DOES NOT DEFINE: mercenaries:%s" % n)
    return not missing


def mesh_check():
    """Every ghost mesh must exist in the game's paks.

    A BasicEntity with an object_Model that does not resolve spawns silently and renders
    nothing, so a mistyped path means the projection simply never appears - with no error
    anywhere. Three of the first six paths written here were wrong.
    """
    import glob
    import zipfile
    src = open(DRV, encoding="utf-8", errors="replace").read()
    want = sorted(set(re.findall(r'"(objects/[^"]+\.cgf)"', src)))
    if not want:
        return True
    GAME = r"C:\Program Files\Steam\steamapps\common\KingdomComeDeliverance2\Data"
    have = set()
    for pak in glob.glob(os.path.join(GAME, "IPL_Objects-part*.pak")):
        try:
            for n in zipfile.ZipFile(pak).namelist():
                if n.lower().endswith(".cgf"):
                    have.add(n.lower().replace("\\", "/"))
        except Exception:
            pass
    if not have:
        print("(game paks not readable here - skipping the ghost mesh check)")
        return True
    bad = [w for w in want if w.lower() not in have]
    for w in bad:
        print("GHOST MESH NOT IN THE PAKS: %s" % w)
    print("ghost meshes: %d checked, %d missing" % (len(want), len(bad)))
    return not bad


def load_check():
    """Both the driver AND the atlas it reads must be in mercenaries.lua's LoadScript list.

    An unloaded atlas is not an error: `mercenaries.CampAtlas` is simply nil, the driver
    logs one line and every keypress does nothing. That is exactly what shipping the driver
    without its atlas looked like in game.
    """
    boot = open(os.path.join(ROOT, "data", "Scripts", "mods", "mercenaries.lua"),
                encoding="utf-8", errors="replace").read()
    bad = []
    for name in ("mercenaries_campatlas.lua", "mercenaries_campui.lua",
                 "mercenaries_delivery.lua"):
        if 'LoadScript("Scripts/mods/%s")' % name not in boot:
            bad.append(name)
    for n in bad:
        print("NOT LOADED by mercenaries.lua: %s" % n)
    # and the atlas has to come first, since the driver reads it at load
    if not bad:
        ia = boot.index('LoadScript("Scripts/mods/mercenaries_campatlas.lua")')
        iu = boot.index('LoadScript("Scripts/mods/mercenaries_campui.lua")')
        if ia > iu:
            print("LOAD ORDER: the atlas must be loaded before the driver")
            return False
    return not bad


def parse_check():
    """The driver has to be valid Lua.

    Every other check here reads the file as text, so a broken edit sails through them all
    and only fails in game, where a script that will not compile takes its whole module with
    it. Needs luaparser; skipped with a note if it is not installed.
    """
    try:
        from luaparser import ast as lua_ast
    except Exception:
        print("(luaparser not installed - skipping the Lua parse check)")
        return True
    ok = True
    for name in ("mercenaries_campui.lua", "mercenaries_campatlas.lua",
                 "mercenaries_delivery.lua",
                 "mercenaries_blui.lua", "mercenaries_blatlas.lua"):
        path = os.path.join(ROOT, "data", "Scripts", "mods", name)
        try:
            lua_ast.parse(open(path, encoding="utf-8", errors="replace").read())
        except Exception as e:
            print("LUA WILL NOT PARSE: %s -> %s" % (name, str(e)[:120]))
            ok = False
    return ok


def loc_check():
    """Every on-screen message key the driver uses must have a localisation row.

    A key with no row is not an error in game - the raw key is printed on screen instead,
    which is how "merc_camp_stowed" would have reached the player.
    """
    src = open(DRV, encoding="utf-8", errors="replace").read()
    src += open(os.path.join(ROOT, "data", "Scripts", "mods", "mercenaries_delivery.lua"),
                encoding="utf-8", errors="replace").read()
    keys = sorted(set(re.findall(r"SendInfoText\(\s*'(\w+)'", src)
                      + re.findall(r"=\s*'(merc_\w+)'", src)))
    if not keys:
        return True
    loc = open(os.path.join(ROOT, "localization", "English_xml.xml"),
               encoding="utf-8", errors="replace").read()
    bad = [k for k in keys if ("<Cell>%s</Cell>" % k) not in loc]
    for k in bad:
        print("NO LOCALISATION ROW: %s" % k)
    print("message keys: %d checked, %d missing" % (len(keys), len(bad)))
    return not bad


def activation_check():
    """Player.OnAction hands Lua "press" and "release", not "onPress"/"onRelease".

    Getting that wrong is invisible: the action still arrives, the handler still consumes
    it, and the key silently does nothing - which is exactly how the camp row was dead for
    three rounds. mercenaries_tower.lua has matched "press" correctly since long before.
    """
    bad = []
    mods = os.path.join(ROOT, "data", "Scripts", "mods")
    for fn in sorted(os.listdir(mods)):
        if not fn.endswith(".lua"):
            continue
        src = open(os.path.join(mods, fn), encoding="utf-8", errors="replace").read()
        for m in re.finditer(r'activation\s*==\s*"(\w+)"', src):
            if m.group(1) not in ("press", "release", "hold"):
                bad.append("%s: activation == %r" % (fn, m.group(1)))
    for b in bad:
        print("NOT AN ENGINE ACTIVATION WORD: %s" % b)
    return not bad


def hint_geometry_check():
    """Both atlases must carry every corner anchor the drivers read off them.

    The corner hints are positioned from atlas keys (merc_hints_pos picks between them).
    A missing key is not an error in Lua - it reads nil, the fallback in HintRowXY takes
    over, and the two screens' nudges quietly stop lining up with each other.
    """
    need = ("hintLeftX", "hintRightX", "hintCompassX", "hintTopY", "hintBottomY",
            "hintRowDY", "hintGap", "hintEdge")
    ok = True
    for name in ("mercenaries_campatlas.lua", "mercenaries_blatlas.lua"):
        src = open(os.path.join(ROOT, "data", "Scripts", "mods", name),
                   encoding="utf-8", errors="replace").read()
        for k in need:
            if not re.search(r"\b%s\s*=" % k, src):
                print("ATLAS IS MISSING A HINT ANCHOR: %s in %s" % (k, name))
                ok = False
    # and the two screens must sit on different rows of that column, or they overlap
    rows = []
    for name in ("mercenaries_campatlas.lua", "mercenaries_blatlas.lua"):
        src = open(os.path.join(ROOT, "data", "Scripts", "mods", name),
                   encoding="utf-8", errors="replace").read()
        m = re.search(r"hintRowDY\s*=\s*(-?[\d.]+)", src)
        rows.append(float(m.group(1)) if m else None)
    if None not in rows and rows[0] == rows[1]:
        print("BOTH SCREENS' NUDGES SIT ON THE SAME ROW (hintRowDY=%s): they will overlap"
              % rows[0])
        ok = False
    return ok


def command_check():
    """Keys are bound to console commands; those must exist WITHOUT merc_dev."""
    src = open(DRV, encoding="utf-8", errors="replace").read()
    player = set(re.findall(r'PlayerCommand\("([\w]+)"', src))
    player |= set(re.findall(r'PlayerCommand\("([\w]+)"\s*\.\.', src))
    bad = [n for n in ("merc_camp_ui", "merc_camp_ui_k") if n not in player]
    bl = open(os.path.join(ROOT, "data", "Scripts", "mods", "mercenaries_blui.lua"),
              encoding="utf-8", errors="replace").read()
    blp = set(re.findall(r'PlayerCommand\("([\w]+)"', bl))
    bad += [n for n in ("merc_hints", "merc_hints_pos") if n not in blp]
    for n in bad:
        print("BOUND TO A KEY BUT NOT A PlayerCommand: %s" % n)
    return not bad


def main():
    have, xml = declared()
    want = wanted()
    missing = sorted(want - have)
    not_in_xml = sorted(want - xml)

    print("atlas declares %d clips, driver can request %d" % (len(have), len(want)))
    if missing:
        print("MISSING from the atlas (%d):" % len(missing))
        for n in missing[:40]:
            print("   ", n)
    if not_in_xml:
        print("MISSING from MercCamp.xml (%d):" % len(not_in_xml))
        for n in not_in_xml[:20]:
            print("   ", n)

    ok = (not missing and not not_in_xml and lua_scope_check()
          and handler_check() and command_check() and mesh_check()
          and activation_check() and hint_geometry_check()
          and load_check() and parse_check() and loc_check())
    print("PASS" if ok else "FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
