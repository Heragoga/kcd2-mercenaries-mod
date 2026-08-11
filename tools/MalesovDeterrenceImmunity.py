"""Grant the mercenaries deterrenceImmunity in utokNaMalesov - single-variable test.

WHAT THE DETERRENT AREA ACTUALLY DOES
  Level data: a SmartAreaShape `sa_deterArea` (template b19f417c... = sa_deterrentArea) covers the
  fortress, 60m high, linked to four `deterredSpot` TagPoints and to itself with the tag
  `instantlyTeleportAway`. Its behaviour `interrupt_beDeterred`
  (references/AI/world/sa_deterrentArea.xml) collects the deterredSpots and, because the
  instantlyTeleportAway link exists, sets `$teleport = true` and MOVES the NPC out of the fortress.
  Deterrence is EVICTION, not unrendering - but an evicted merc is absent from the battle, which
  looks the same from the player's side.

  hibernovana_cast/deterrent_area.xml grants `deterrenceImmunity` to a JoinArrays of exactly six
  aliases: zizkaband, outerCourtyardDefendersAndShooters, malesovTowerShooters,
  innerCourtyardDefenders_basicCrew, towerDefenders, roza. Anyone else inside the area is evicted.

WHY THIS SCRIPT DOES IT BY EXTENDING joinarrays52 RATHER THAN ADDING A NODE
  Adding a new <SetEntityContext> needs an IsActive port wired from a bool source (a Constant does
  not work - a malformed IsActive is silently rejected, which cost us several sessions), and Souls
  is an Asset port that takes <Asset Name="Souls" Alias="..."/>, never an <Edge>. Extending the
  existing JoinArrays reuses vanilla's already-working wiring: no new node, no IsActive, no risk.
  JoinArrays accepts inputs A..O; joinarrays52 uses A..F, so G is free.

SINGLE VARIABLE: this makes the deterrence change and NOTHING else. No soul injection into other
assets, so a positive result is unambiguous. Run OverrideMainQuestBattles.py afterwards if you
want the broader injection back.

    python tools/MalesovDeterrenceImmunity.py
    python tools/MalesovDeterrenceImmunity.py --revert
"""

import argparse
import re
import shutil
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
REL = Path("Quests/Final/Barbora/kutnohorsko/utokNaMalesov")
SRC_DIR, SRC_FILE = REPO / "references" / REL, REPO / "references" / REL.with_suffix(".xml")
DST_DIR, DST_FILE = REPO / "data" / REL, REPO / "data" / REL.with_suffix(".xml")
DETERRENT = "hibernovana_cast/deterrent_area.xml"

MERC_SRC = REPO / "data/quests/mercenaries/kutnohorsko/mercenaries_background_quest.xml"
ALIAS = "mercenaries_mercs"


def read(p):
    raw = p.read_bytes()
    try:
        return raw.decode("utf-8"), "utf-8"
    except UnicodeDecodeError:
        return raw.decode("cp1252"), "cp1252"


def write(p, text, encoding):
    with open(p, "w", encoding=encoding, newline="") as fh:
        fh.write(text)


def merc_souls():
    t, _ = read(MERC_SRC)
    m = re.search(r'<SoulAsset Name="mercs" SharedSoulGuids="([^"]*)"', t)
    if not m:
        raise SystemExit("ERROR: no 'mercs' SoulAsset in %s" % MERC_SRC)
    return m.group(1).split()


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
    args = ap.parse_args()
    if args.revert:
        revert(); return 0

    souls = merc_souls()
    print("merc souls: %d" % len(souls))

    # fresh copy so the change is the only difference from vanilla
    if DST_DIR.exists():
        shutil.rmtree(DST_DIR)
    DST_DIR.parent.mkdir(parents=True, exist_ok=True)
    shutil.copytree(SRC_DIR, DST_DIR)
    shutil.copy2(SRC_FILE, DST_FILE)
    print("copied %d files" % (len(list(DST_DIR.rglob('*.xml'))) + 1))

    # 1. declare the alias in the top-level <Assets> block so every descendant module sees it
    t, enc = read(DST_FILE)
    if ALIAS in t:
        print("alias already present in top-level quest")
    else:
        node = '\t\t\t\t<SoulAsset Name="%s" SharedSoulGuids="%s" />\n' % (ALIAS, " ".join(souls))
        i = t.find("\t\t\t</Assets>")
        if i == -1:
            i = t.find("</Assets>")
            if i == -1:
                raise SystemExit("ERROR: no </Assets> in %s" % DST_FILE)
        t = t[:i] + node + t[i:]
        write(DST_FILE, t, enc)
        print("declared <SoulAsset Name=\"%s\"> with %d guids in utokNaMalesov.xml" % (ALIAS, len(souls)))

    # 2. add it as input G of joinarrays52, which already feeds the deterrenceImmunity node
    dp = DST_DIR / DETERRENT
    t, enc = read(dp)
    if 'Alias="%s"' % ALIAS in t:
        print("deterrent_area.xml already extended")
    else:
        anchor = '<Asset Name="F" Alias="roza" />'
        if anchor not in t:
            raise SystemExit("ERROR: joinarrays52 anchor not found in %s" % dp)
        t = t.replace(anchor, anchor + '\n\t\t\t\t\t<Asset Name="G" Alias="%s" />' % ALIAS, 1)
        write(dp, t, enc)
        print("added <Asset Name=\"G\" Alias=\"%s\" /> to joinarrays52" % ALIAS)

    # verify: exactly the two files should differ from vanilla
    import subprocess
    r = subprocess.run(["diff", "-rq", str(SRC_DIR), str(DST_DIR)],
                       capture_output=True, text=True)
    differing = [l for l in r.stdout.splitlines() if l.strip()]
    print("\nsubtree files differing from vanilla: %d (expect 1 - deterrent_area.xml)" % len(differing))
    for l in differing:
        print("   ", l)
    print("top-level utokNaMalesov.xml: alias declared =", ALIAS in read(DST_FILE)[0])
    print("\nrun PackageModDev.bat, then fight Malesov and watch whether mercs stay in the fortress")
    return 0


if __name__ == "__main__":
    sys.exit(main())
