"""Make the Malesov garrison hostile TO the mercenaries - the reverse faction relation.

THE MECHANISM (docs/malesov-structure.md)
  `AddFactionRelationBetweenArrays` is the only node in utokNaMalesov that creates combat
  hostility between the scripted armies. 6 instances, all RelationValue="-1", ports
  SoulArray0 / SoulArray1. It is DIRECTIONAL: Array0 becomes hostile toward Array1, so being in
  **SoulArray1 is what makes something attack you**.

  Every SoulArray1 in this quest is a garrison roster. That is why:
    all 137 assets injected -> merc landed in SoulArray1 -> targeted -> RENDERED (but fought for
                               the garrison, because it was literally in the enemy array)
    ally 67 / 6 companions  -> merc only ever in SoulArray0 -> nothing targeted it -> invisible

  Corroboration: the mod's own FactionTree declares mercenariesFaction -1 toward the vanilla enemy
  factions, but NO vanilla faction declares anything toward mercenariesFaction. One-directional
  again. Mercs attack; nothing attacks back; nothing engages them; no combat actor; ambient LOD.

WHAT THIS DOES
  For each of the 6 existing relation nodes, add a MIRROR node:
      SoulArray0 = whatever the original fed to SoulArray1   (the garrison)
      SoulArray1 = <Asset Alias="mercenaries_mercs">          (our 83 souls)
      RelationValue = -1, IsActive = the original's own source
  The garrison becomes hostile toward the mercs WITHOUT the mercs joining the garrison - so they
  get engaged and rendered while staying loyal.

  <Asset Name="SoulArray0/1" Alias="..."/> is a verified vanilla form (34 and 20 uses), so no new
  JoinArrays is needed. IsActive is copied from the original edge (Vertex children dropped - they
  are only cosmetic routing).

    python tools/MalesovMercHostility.py
    python tools/MalesovMercHostility.py --with-deterrence   # also grant deterrenceImmunity
    python tools/MalesovMercHostility.py --revert
"""

import argparse
import re
import shutil
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
REL = Path("Quests/Final/Barbora/kutnohorsko/utokNaMalesov")
SRC_DIR, SRC_FILE = REPO / "references" / REL, REPO / "references" / REL.with_suffix(".xml")
DST_DIR, DST_FILE = REPO / "data" / REL, REPO / "data" / REL.with_suffix(".xml")
MERC_SRC = REPO / "data/quests/mercenaries/kutnohorsko/mercenaries_background_quest.xml"
ALIAS = "mercenaries_mercs"

NODE = re.compile(r'<AddFactionRelationBetweenArrays\b[^>]*>.*?</AddFactionRelationBetweenArrays>', re.S)
NAME = re.compile(r'<AddFactionRelationBetweenArrays\s+Name="([^"]*)"')


def read(p):
    raw = p.read_bytes()
    try:
        return raw.decode("utf-8"), "utf-8"
    except UnicodeDecodeError:
        return raw.decode("cp1252"), "cp1252"


def write(p, t, enc):
    with open(p, "w", encoding=enc, newline="") as fh:
        fh.write(t)


def merc_souls():
    t, _ = read(MERC_SRC)
    m = re.search(r'<SoulAsset Name="mercs" SharedSoulGuids="([^"]*)"', t)
    if not m:
        raise SystemExit("ERROR: no 'mercs' SoulAsset in %s" % MERC_SRC)
    return m.group(1).split()


def feed_for(block, port):
    """How `port` is fed: ('edge', source) or ('asset', alias) or None."""
    m = re.search(r'<Edge\s+From="([^"]*)"\s+To="%s"\s*/?>' % port, block)
    if m:
        return ("edge", m.group(1))
    m = re.search(r'<Asset\s+Name="%s"\s+Alias="([^"]*)"\s*/>' % port, block)
    if m:
        return ("asset", m.group(1))
    return None


def mirror(block):
    """Build the reversed relation node, or None if the original cannot be read."""
    name = NAME.search(block).group(1)
    src1 = feed_for(block, "SoulArray1")     # becomes our SoulArray0
    active = feed_for(block, "IsActive")
    if not src1 or not active:
        return None, name

    if src1[0] == "edge":
        arr0 = '\t\t\t\t\t<Edge From="%s" To="SoulArray0" />' % src1[1]
    else:
        arr0 = '\t\t\t\t\t<Asset Name="SoulArray0" Alias="%s" />' % src1[1]

    if active[0] == "edge":
        act = '\t\t\t\t\t<Edge From="%s" To="IsActive" />' % active[1]
    else:
        act = '\t\t\t\t\t<Asset Name="IsActive" Alias="%s" />' % active[1]

    return ("\n".join([
        '\t\t\t\t<AddFactionRelationBetweenArrays Name="merc_rev_%s">' % name,
        '\t\t\t\t\t<Constant Name="RelationValue" Value="-1" />',
        arr0,
        act,
        '\t\t\t\t\t<Asset Name="SoulArray1" Alias="%s" />' % ALIAS,
        '\t\t\t\t</AddFactionRelationBetweenArrays>',
    ]), name)


def revert():
    gone = False
    if DST_DIR.exists():
        shutil.rmtree(DST_DIR); print("removed %s" % DST_DIR.relative_to(REPO)); gone = True
    if DST_FILE.exists():
        DST_FILE.unlink(); print("removed %s" % DST_FILE.relative_to(REPO)); gone = True
    if not gone:
        print("nothing to revert")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--revert", action="store_true")
    ap.add_argument("--with-deterrence", action="store_true",
                    help="also add the mercs to the deterrenceImmunity JoinArrays")
    args = ap.parse_args()
    if args.revert:
        revert(); return 0

    souls = merc_souls()
    print("merc souls: %d" % len(souls))

    if DST_DIR.exists():
        shutil.rmtree(DST_DIR)
    DST_DIR.parent.mkdir(parents=True, exist_ok=True)
    shutil.copytree(SRC_DIR, DST_DIR)
    shutil.copy2(SRC_FILE, DST_FILE)

    # declare the alias at top level so every descendant module resolves it
    t, enc = read(DST_FILE)
    if ALIAS not in t:
        node = '\t\t\t\t<SoulAsset Name="%s" SharedSoulGuids="%s" />\n' % (ALIAS, " ".join(souls))
        i = t.find("\t\t\t</Assets>")
        if i == -1:
            i = t.find("</Assets>")
        t = t[:i] + node + t[i:]
        write(DST_FILE, t, enc)
    print('declared <SoulAsset Name="%s"> (%d guids)' % (ALIAS, len(souls)))

    # mirror every relation node
    added, skipped = [], []
    for p in sorted(list(DST_DIR.rglob("*.xml")) + [DST_FILE]):
        t, enc = read(p)
        if "AddFactionRelationBetweenArrays" not in t:
            continue
        out, changed = t, False
        for block in NODE.findall(t):
            if block.lstrip().startswith('<AddFactionRelationBetweenArrays Name="merc_rev_'):
                continue
            mir, name = mirror(block)
            if not mir:
                skipped.append((p.name, name)); continue
            out = out.replace(block, block + "\n" + mir, 1)
            added.append((p.relative_to(DST_DIR.parent).as_posix(), name))
            changed = True
        if changed:
            write(p, out, enc)

    if args.with_deterrence:
        dp = DST_DIR / "hibernovana_cast/deterrent_area.xml"
        t, enc = read(dp)
        anchor = '<Asset Name="F" Alias="roza" />'
        if ALIAS not in t and anchor in t:
            write(dp, t.replace(anchor, anchor + '\n\t\t\t\t\t<Asset Name="G" Alias="%s" />' % ALIAS, 1), enc)
            print("also granted deterrenceImmunity via joinarrays52")

    print("\nmirrored %d relation nodes:" % len(added))
    for f, n in added:
        print("   %-72s %s" % (f, n))
    for f, n in skipped:
        print("   SKIPPED (unreadable ports): %s %s" % (f, n))

    r = subprocess.run(["diff", "-rq", str(SRC_DIR), str(DST_DIR)], capture_output=True, text=True)
    print("\nsubtree files differing from vanilla: %d" %
          len([l for l in r.stdout.splitlines() if l.strip()]))
    print("run PackageModDev.bat, then fight Malesov - the garrison should now ATTACK the mercs")
    return 0


if __name__ == "__main__":
    sys.exit(main())
