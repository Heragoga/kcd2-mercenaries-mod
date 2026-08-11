"""Make the Malesov INNER COURTYARD garrison hostile toward the mercenaries.

WHY THIS SHAPE
  Six tests established: rendering requires something to be hostile TOWARD the merc (i.e. the
  merc must actually be fought), not merely the merc being hostile. AddFactionRelationBetweenArrays
  is directional - SoulArray0 becomes hostile toward SoulArray1:

    merc in Array0 (ally aliases)  -> nobody attacks it            -> INVISIBLE
    merc in Array1 (garrison)      -> player+Zizkaband attack it   -> RENDERS, but fights the player
    inert NPC in Array1, no AI     -> attacked but never fights    -> INVISIBLE
    regular hired mercs, no array  -> attack a garrison that ignores them -> INVISIBLE

  The tower fight (boj_ve_vezi_optional/bitva_ve_vezi.xml:38) is the ONE vanilla relation pointing
  the right way, and its shape is what we copy here:

    <Asset Name="SoulArray0" Alias="towerDefenders" />        <- garrison, hostile TOWARD...
    <Edge From="joinarrays36.Array" To="SoulArray1" />        <- JoinArrays(player + towerAttackers)
    <Edge From="or41.bool" To="IsActive" />

  Crucially the PLAYER sits in SoulArray1 alongside the attackers, which is why no player/attacker
  hostility exists. We replicate that exactly: JoinArrays(player + mercenaries_mercs) as SoulArray1.

WHAT IT ADDS to boj.xml (inner courtyard final fight)
    <Function merc_joinarrays_player_mercs>  = JoinArrays(player, mercenaries_mercs)
    <AddFactionRelationBetweenArrays merc_rev_courtyard>
        SoulArray0 = innerCourtyardDefendersAndShooters   (Asset form, as vanilla's tower node)
        SoulArray1 = merc_joinarrays_player_mercs.Array
        IsActive   = obranci_jdou_bojovat                 (the module's own bool In port,
                                                           already driving 9 vanilla nodes)

  An earlier attempt (tools/MalesovMercHostility.py) mirrored all 6 relation nodes but put ONLY
  merc souls in SoulArray1 and fed SoulArray0 by Edge; it had no effect. Scope was ruled out
  afterwards (boj.xml declares no assets at all and inherits everything), as was the activation
  source (obranci_jdou_bojovat is a sustained bool In port, not a one-shot trigger). The remaining
  untested difference is this node shape - hence copying the working vanilla one literally.

  TIMING: spawn mercs BEFORE the courtyard fight starts. A soul array resolves against souls that
  exist when the node evaluates.

    python tools/MalesovCourtyardHostility.py
    python tools/MalesovCourtyardHostility.py --revert
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
BOJ = "hibernovana_cast/tvrz/finalni_boj_o_hrad/boj_na_vnitrnim_nadvori/boj.xml"

MERC_SRC = REPO / "data/quests/mercenaries/kutnohorsko/mercenaries_background_quest.xml"
ALIAS = "mercenaries_mercs"
GARRISON = "innerCourtyardDefendersAndShooters"


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

    if DST_DIR.exists():
        shutil.rmtree(DST_DIR)
    DST_DIR.parent.mkdir(parents=True, exist_ok=True)
    shutil.copytree(SRC_DIR, DST_DIR)
    shutil.copy2(SRC_FILE, DST_FILE)

    # 1. declare the merc alias at top level (boj.xml has no Assets block and inherits)
    t, enc = read(DST_FILE)
    if ALIAS not in t:
        node = '\t\t\t\t<SoulAsset Name="%s" SharedSoulGuids="%s" />\n' % (ALIAS, " ".join(souls))
        i = t.find("\t\t\t</Assets>")
        if i == -1:
            i = t.find("</Assets>")
            if i == -1:
                raise SystemExit("ERROR: no </Assets> in %s" % DST_FILE)
        t = t[:i] + node + t[i:]
        write(DST_FILE, t, enc)
    print('declared <SoulAsset Name="%s"> (%d guids)' % (ALIAS, len(souls)))

    # 2. add the JoinArrays + reversed relation into boj.xml, copying the tower node's shape
    bp = DST_DIR / BOJ
    t, enc = read(bp)
    if "merc_rev_courtyard" in t:
        print("boj.xml already patched")
    else:
        block = "\n".join([
            '\t\t\t\t<Function Name="merc_joinarrays_player_mercs" PositionY="1400" PositionX="60" TypeT="wh::rpgmodule::Souls" MethodName="utilities::array::JoinArrays" DeclaringType="utilities::array">',
            '\t\t\t\t\t<Asset Name="A" Alias="player" />',
            '\t\t\t\t\t<Asset Name="B" Alias="%s" />' % ALIAS,
            '\t\t\t\t</Function>',
            '\t\t\t\t<AddFactionRelationBetweenArrays Name="merc_rev_courtyard" PositionY="1500" PositionX="450">',
            '\t\t\t\t\t<Constant Name="RelationValue" Value="-1" />',
            '\t\t\t\t\t<Asset Name="SoulArray0" Alias="%s" />' % GARRISON,
            '\t\t\t\t\t<Edge From="merc_joinarrays_player_mercs.Array" To="SoulArray1" />',
            '\t\t\t\t\t<Edge From="obranci_jdou_bojovat" To="IsActive" />',
            '\t\t\t\t</AddFactionRelationBetweenArrays>',
        ])
        i = t.rindex("\t\t\t</Nodes>")
        t = t[:i] + block + "\n" + t[i:]
        write(bp, t, enc)
        print("patched %s" % BOJ)
        print("  SoulArray0 = %s   (garrison, hostile TOWARD ->)" % GARRISON)
        print("  SoulArray1 = JoinArrays(player, %s)" % ALIAS)
        print("  IsActive   = obranci_jdou_bojovat")

    r = subprocess.run(["diff", "-rq", str(SRC_DIR), str(DST_DIR)], capture_output=True, text=True)
    diffs = [l for l in r.stdout.splitlines() if l.strip()]
    print("\nsubtree files differing from vanilla: %d (expect 1 - boj.xml)" % len(diffs))
    for l in diffs:
        print("   ", l)
    print("\nrun PackageModDev.bat. SPAWN MERCS BEFORE the courtyard fight starts.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
