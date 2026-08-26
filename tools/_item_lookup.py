"""Name -> GUID lookup over the vanilla item tables in references/Libs/Tables/item."""
import re, glob, os

BASE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..",
                    "references", "Libs", "Tables", "item")

def load_items():
    items = {}
    for f in glob.glob(os.path.join(BASE, "item*.xml")):
        txt = open(f, encoding="utf-8", errors="replace").read()
        for m in re.finditer(r'<(\w+)\s([^>]*?)/>', txt):
            tag, attrs = m.group(1), m.group(2)
            iid = re.search(r'\bId="([0-9a-fA-F\-]{36})"', attrs)
            nm = re.search(r'\bName="([^"]*)"', attrs)
            if not iid or not nm:
                continue
            d = 0.0
            for k in ("DefenseStab", "DefenseSlash", "DefenseSmash"):
                x = re.search(r'\b%s="([\d\.]+)"' % k, attrs)
                if x:
                    d += float(x.group(1))
            items[nm.group(1)] = (iid.group(1), d, tag)
    return items

if __name__ == "__main__":
    import sys
    it = load_items()
    for pat in sys.argv[1:]:
        rx = re.compile(pat, re.I)
        hits = sorted(k for k in it if rx.search(k))
        print("## %s (%d)" % (pat, len(hits)))
        for h in hits[:40]:
            g, d, t = it[h]
            print("   %-44s %-14s %5.0f  %s" % (h, t, d, g))
