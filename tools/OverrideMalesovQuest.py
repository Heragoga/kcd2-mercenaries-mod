"""Copy the vanilla utokNaMalesov quest into the mod so it overrides the original,
appending the mercenary test soul GUID to every SoulAsset in it.

Experiment (see docs/quest-override-test.md): main quests list the souls they care
about in SoulAsset nodes; if that membership is what makes the game render an NPC
during a scripted battle, a merc soul present in every one of them should render too.

    python tools/OverrideMalesovQuest.py            # write the override
    python tools/OverrideMalesovQuest.py --revert   # delete it again

Idempotent: re-running re-copies from references/ and re-injects, so it never
double-appends. Reads only from references/, writes only under data/Quests/.
"""

import argparse
import re
import shutil
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent

QUEST_REL = Path("Quests/Final/Barbora/kutnohorsko/utokNaMalesov")
SRC_DIR = REPO / "references" / QUEST_REL
SRC_FILE = REPO / "references" / QUEST_REL.with_suffix(".xml")
DST_DIR = REPO / "data" / QUEST_REL
DST_FILE = REPO / "data" / QUEST_REL.with_suffix(".xml")

# mercenaries.TestSoulGuid in data/Scripts/mods/mercenaries_spawning.lua.
# merc_testmerc spawns exactly this soul; keep the two in sync.
TEST_SOUL = "e1f2a3b4-1234-4efa-c890-123456789012"

# Matches a whole SoulAsset node so the alias name can gate the injection.
SOUL_NODE = re.compile(r'<SoulAsset Name="([^"]*)"\s+SharedSoulGuids="([^"]*)"')

# The Malesov garrison - the side the player is attacking. Injecting into these is
# what made the test merc hostile: the quest's own relation and behaviour nodes
# treated it as a defender. Everything not matching this (and not a villager) is
# Zizka's side, i.e. the player's.
ENEMY_PAT = re.compile(
    r"(Defender|defender"
    r"|Shooter|shooter"
    r"|[Bb]asicCrew"
    r"|towerDefend"
    r"|malesovTower"
    r"|malesovWatchman"
    r"|desatnik"
    r"|bergov"
    r"|poacher"
    r"|outerCourtyardReinforcements"
    r"|outerCourtyardBurnedVillageReinforcements)"
)

# Non-combatants; no reason to enrol a merc in these.
VILLAGER_PAT = re.compile(
    r"(Villager|villager"
    r"|fleeingWoman|mourningVillager|dyingVillager|chattingWoman"
    r"|deadVillagers|barkingSouls|dialogueTorchBearers|certovkaEveningMeetup)"
)


def side_of(name):
    """ally | enemy | villager - by SoulAsset alias name."""
    # Zizkaband entries can contain 'Shooter'-ish words, so ally wins first.
    if re.search(r"(zizka|Zizka|brabant|Brabant|villageReinforc|villageReinfroc"
                 r"|additionalVillageReinforcement|towerAttackers|villageAssaultUnit"
                 r"|stealthCommando|stealthPolylog)", name):
        return "ally"
    if VILLAGER_PAT.search(name):
        return "villager"
    if ENEMY_PAT.search(name):
        return "enemy"
    return "ally"


def inject(text, selector, souls):
    """Append each of `souls` to every SharedSoulGuids whose alias passes `selector`."""
    count = 0
    names = []

    def repl(m):
        nonlocal count
        name, guid_str = m.group(1), m.group(2)
        if not selector(name):
            return m.group(0)
        guids = guid_str.split()
        new = [s for s in souls if s not in guids]
        if not new:
            return m.group(0)
        guids.extend(new)
        count += 1
        names.append(name)
        return '<SoulAsset Name="%s" SharedSoulGuids="%s"' % (name, " ".join(guids))

    return SOUL_NODE.sub(repl, text), count, names


def revert():
    removed = False
    if DST_DIR.exists():
        shutil.rmtree(DST_DIR)
        print("removed %s" % DST_DIR.relative_to(REPO))
        removed = True
    if DST_FILE.exists():
        DST_FILE.unlink()
        print("removed %s" % DST_FILE.relative_to(REPO))
        removed = True
    # tidy up now-empty parents, but never touch data/ itself
    for parent in list(DST_DIR.parents):
        if parent == REPO / "data":
            break
        if parent.exists() and not any(parent.iterdir()):
            parent.rmdir()
    if not removed:
        print("nothing to revert")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--revert", action="store_true", help="delete the override")
    ap.add_argument("--group", default="ally",
                    choices=["ally", "all", "enemy", "villager"],
                    help="which side's SoulAssets to inject into (default: ally, "
                         "which avoids the hostile-merc problem)")
    ap.add_argument("--assets", metavar="REGEX",
                    help="inject only into SoulAssets whose alias matches this "
                         "regex - use to bisect which asset grants the render")
    ap.add_argument("--list", action="store_true",
                    help="just print every SoulAsset alias and its side, change nothing")
    ap.add_argument("--extra-soul", metavar="GUID", action="append", default=[],
                    help="inject an ADDITIONAL soul guid alongside TEST_SOUL into the same "
                         "assets - repeatable. Use to put two different test entities "
                         "(e.g. a regular merc soul and the isolation-test soul) in the "
                         "exact same SoulArray for a same-session comparison.")
    args = ap.parse_args()
    souls = [TEST_SOUL] + args.extra_soul

    if args.revert:
        revert()
        return 0

    if args.list:
        seen = {}
        for path in list(SRC_DIR.rglob("*.xml")) + [SRC_FILE]:
            raw = path.read_bytes()
            try:
                text = raw.decode("utf-8")
            except UnicodeDecodeError:
                text = raw.decode("cp1252")
            for m in SOUL_NODE.finditer(text):
                seen[m.group(1)] = side_of(m.group(1))
        for side in ("ally", "enemy", "villager"):
            members = sorted(n for n, s in seen.items() if s == side)
            print("--- %s (%d) ---" % (side, len(members)))
            for n in members:
                print("   ", n)
        return 0

    if args.assets:
        pat = re.compile(args.assets)
        selector = lambda n: bool(pat.search(n))
        label = "assets matching /%s/" % args.assets
    elif args.group == "all":
        selector = lambda n: True
        label = "ALL sides (will make the merc hostile - see docs)"
    else:
        selector = lambda n: side_of(n) == args.group
        label = "%s-side assets only" % args.group

    if not SRC_DIR.is_dir() or not SRC_FILE.is_file():
        print("ERROR: vanilla quest not found under references/", file=sys.stderr)
        print("  expected %s" % SRC_DIR, file=sys.stderr)
        return 1

    # Always start from a clean copy so re-runs cannot compound edits.
    if DST_DIR.exists():
        shutil.rmtree(DST_DIR)
    DST_DIR.parent.mkdir(parents=True, exist_ok=True)
    shutil.copytree(SRC_DIR, DST_DIR)
    shutil.copy2(SRC_FILE, DST_FILE)

    files = sorted(list(DST_DIR.rglob("*.xml")) + [DST_FILE])
    total_files, total_assets, touched_files = 0, 0, 0
    all_names = set()

    for path in files:
        total_files += 1
        raw = path.read_bytes()
        try:
            text = raw.decode("utf-8")
            encoding = "utf-8"
        except UnicodeDecodeError:
            text = raw.decode("cp1252")
            encoding = "cp1252"

        new_text, n, names = inject(text, selector, souls)
        if n:
            # newline="" keeps the original line endings byte-for-byte
            with open(path, "w", encoding=encoding, newline="") as fh:
                fh.write(new_text)
            touched_files += 1
            total_assets += n
            all_names.update(names)

    print("scope:  %s" % label)
    print("copied  %d xml files" % total_files)
    print("touched %d files" % touched_files)
    print("injected test soul into %d SharedSoulGuids lists" % total_assets)
    print("souls: %s" % ", ".join(souls))
    if all_names:
        print()
        print("assets injected (%d unique):" % len(all_names))
        for n in sorted(all_names):
            print("   ", n)
    if total_assets == 0:
        print()
        print("WARNING: nothing was injected - the override is a plain vanilla copy.")
    print()
    print("override lives at data/%s[.xml]" % QUEST_REL)
    print("run PackageMod.bat, then merc_testmerc in game")
    return 0


if __name__ == "__main__":
    sys.exit(main())
