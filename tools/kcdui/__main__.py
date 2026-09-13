"""python tools/kcdui <command>

    build  <scene.json> [--root DIR] [--preview OUT.png] [--scale 1.5]
    check  <file.swf> [--xml FILE] [--lua FILE]
    show   <file.swf>
    fonts
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from kcdui import scene as SC          # noqa: E402
from kcdui import verify as V          # noqa: E402
from kcdui import fonts as F           # noqa: E402


def _opt(argv, name, default=None):
    if name in argv:
        i = argv.index(name)
        return argv[i + 1]
    return default


def cmd_build(argv):
    if not argv:
        print("build needs a scene file"); return 2
    path = argv[0]
    A, written = SC.build(path, root=_opt(argv, "--root"),
                          preview_path=_opt(argv, "--preview"),
                          scale=float(_opt(argv, "--scale", 1.5)))
    print("%s  %d clips, %d unique images" % (A.element, len(A.names), len(A.shapes)))
    for what in ("swf", "xml", "lua"):
        if what in written:
            p, n = written[what]
            print("  %-3s %s  (%s)" % (what, p, "%d bytes" % n if what == "swf"
                                       else "%d clips" % n))
    if _opt(argv, "--preview"):
        print("  png %s" % _opt(argv, "--preview"))

    if "swf" in written:
        bad = V.cross_check(written["swf"][0],
                            written["xml"][0] if "xml" in written else None,
                            list(A.meta))
        for b in bad:
            print("  MISMATCH: %s" % b)
        if bad:
            return 1
        print("  ok: the SWF, the XML and the Lua all name the same %d clips" % len(A.names))
    return 0


def cmd_check(argv):
    if not argv:
        print("check needs a .swf"); return 2
    lua_names = None
    lua = _opt(argv, "--lua")
    if lua:
        src = open(lua, encoding="utf-8", errors="replace").read()
        lua_names = re.findall(r'\["([^"]+)"\]\s*=\s*\{\s*w\s*=', src)
    bad = V.cross_check(argv[0], _opt(argv, "--xml"), lua_names)
    print(V.describe(argv[0]))
    for b in bad:
        print("  MISMATCH: %s" % b)
    print("  %s" % ("PASS" if not bad else "FAIL"))
    return 0 if not bad else 1


def cmd_show(argv):
    if not argv:
        print("show needs a .swf"); return 2
    print(V.describe(argv[0]))
    return 0


def cmd_fonts(argv):
    if F.available():
        print("the game's own typefaces are readable: %s" % ", ".join(F.FACES))
        for f in F.FACES:
            try:
                print("  %-8s 'Supplies' at 19px measures %s" % (f, F.measure("Supplies", 19, f)))
            except Exception as e:
                print("  %-8s FAILED: %s" % (f, e))
        return 0
    print("the game's fonts are NOT readable here - text will fall back to a system face.")
    print("kcd_font.py reads Libs/UI/gfxfontlib_glyphs.gfx out of IPL_GameData.pak;")
    print("check the GAME path at the top of tools/kcd_font.py.")
    return 1


def main(argv):
    cmds = {"build": cmd_build, "check": cmd_check, "show": cmd_show, "fonts": cmd_fonts}
    if not argv or argv[0] not in cmds:
        print(__doc__)
        return 2
    return cmds[argv[0]](argv[1:])


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
