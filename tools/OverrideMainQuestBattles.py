"""Override every main-quest battle with copies that list the mercenary souls.

Generalises tools/OverrideMalesovQuest.py from one quest to all of them.

Why: quest SoulAsset membership is the only thing measured to make mercs render in a
scripted battle (docs/npc-lod.md runs 36-44). Faction, LOD cvars, battle contexts and
quest type all failed. This ships the thing that works.

A "main-quest battle" is a quest whose <Quest> node has NO Type attribute (that is what
a main story quest is - Type marks Activity/Side/Micro/Racing) and whose file or folder
contains battle machinery.

    python tools/OverrideMainQuestBattles.py --list          # preview, change nothing
    python tools/OverrideMainQuestBattles.py                 # write the overrides
    python tools/OverrideMainQuestBattles.py --scope noHostile
    python tools/OverrideMainQuestBattles.py --revert        # remove them all

Idempotent: always re-copies from references/ before injecting, so it cannot
double-append. Reads only references/, writes only data/Quests/.
"""

import argparse
import re
import shutil
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
SRC_ROOT = REPO / "references" / "Quests"
DST_ROOT = REPO / "data" / "Quests"

# DANGER: on Windows `data/Quests` and `data/quests` are the SAME directory, and
# `data/quests/mercenaries*` holds this mod's own quests (hire/dismissal/quartermaster
# dialogs, gossips, barks, monologs - 155 files). Deleting DST_ROOT wholesale destroys
# them; that is exactly what an earlier version of this script did.
#
# Everything this tool generates lives under Quests/Final/, so that subtree - and ONLY
# that subtree - is what we ever remove.
MANAGED = DST_ROOT / "Final"


def assert_not_ours(path):
    """Refuse to touch anything under data/quests/mercenaries*.

    Must inspect the path RELATIVE to the repo: the absolute path contains
    'mercenaries' from the checkout's own folder names, which made an earlier
    version of this guard refuse every delete including legitimate ones.
    """
    try:
        parts = [p.lower() for p in path.resolve().relative_to(REPO).parts]
    except ValueError:
        raise SystemExit("REFUSING to touch a path outside the repo: %s" % path)
    if "mercenaries" in parts or any(p.startswith("mercenaries.") for p in parts):
        raise SystemExit("REFUSING to touch mod-owned quest path: %s" % path)

# Souls to inject: the curated list our own background quest already carries.
MERC_SOUL_ASSET = REPO / "data/quests/mercenaries/kutnohorsko/mercenaries_background_quest.xml"

QUEST_NODE = re.compile(r"<Quest ([^>]*)>")
TYPE_ATTR = re.compile(r'Type="([^"]*)"')
SOUL_NODE = re.compile(r'<SoulAsset Name="([^"]*)"\s+SharedSoulGuids="([^"]*)"')

BATTLE_MARKERS = (
    "crime_global_battleInProgress",
    "battleGroupController",
    "RequestBattleNPC",
    "BattleDirector",
    "battleLadderController",
    "battleWakingController",
)

# Assets consumed by these node types get behaviour or relations forced on them by the
# quest. Injecting a merc there is what made the first test merc fight for the garrison.
HOSTILE_CONSUMERS = ("EnableBehavior", "SetRelationContext")


def read(path):
    raw = path.read_bytes()
    try:
        return raw.decode("utf-8"), "utf-8"
    except UnicodeDecodeError:
        return raw.decode("cp1252"), "cp1252"


def merc_souls():
    text, _ = read(MERC_SOUL_ASSET)
    m = re.search(r'<SoulAsset Name="mercs" SharedSoulGuids="([^"]*)"', text)
    if not m:
        raise SystemExit("ERROR: could not find the 'mercs' SoulAsset in %s" % MERC_SOUL_ASSET)
    return m.group(1).split()


def quest_files(quest_path):
    """A quest file plus its same-named sibling folder."""
    files = [quest_path]
    folder = quest_path.with_suffix("")
    if folder.is_dir():
        files += sorted(folder.rglob("*.xml"))
    return files


def discover():
    """Main quests (no Type attribute) under Final/ that contain battle machinery."""
    found = []
    final = SRC_ROOT / "Final"
    if not final.is_dir():
        raise SystemExit("ERROR: %s not found" % final)

    # One pass: cache every file's text, since quests share folders.
    cache = {}
    for p in final.rglob("*.xml"):
        try:
            cache[p] = read(p)[0]
        except Exception:
            cache[p] = ""

    for p, text in cache.items():
        m = QUEST_NODE.search(text)
        if not m or TYPE_ATTR.search(m.group(1)):
            continue  # not a quest node, or a typed (non-main) quest
        files = quest_files(p)
        blob = "".join(cache.get(f, "") for f in files)
        if not any(marker in blob for marker in BATTLE_MARKERS):
            continue
        found.append((p, files, sum(blob.count(mk) for mk in BATTLE_MARKERS),
                      blob.count("SharedSoulGuids=")))
    found.sort(key=lambda r: -r[3])
    return found


def hostile_assets(files, cache):
    """Alias names consumed by EnableBehavior / SetRelationContext nodes."""
    names = set()
    for f in files:
        text = cache.get(f)
        if text is None:
            continue
        for node in HOSTILE_CONSUMERS:
            for m in re.finditer(r"<%s\b.*?</%s>" % (node, node), text, re.S):
                names.update(re.findall(r'Alias="([^"]*)"', m.group(0)))
            # self-closing / attribute-only forms
            for m in re.finditer(r"<%s\b[^>]*/>" % node, text):
                names.update(re.findall(r'Alias="([^"]*)"', m.group(0)))
    return names


def inject(text, souls, skip_names):
    added_lists = 0
    added_guids = 0

    def repl(m):
        nonlocal added_lists, added_guids
        name, guid_str = m.group(1), m.group(2)
        if name in skip_names:
            return m.group(0)
        guids = guid_str.split()
        new = [g for g in souls if g not in guids]
        if not new:
            return m.group(0)
        guids.extend(new)
        added_lists += 1
        added_guids += len(new)
        return '<SoulAsset Name="%s" SharedSoulGuids="%s"' % (name, " ".join(guids))

    return SOUL_NODE.sub(repl, text), added_lists, added_guids


def revert():
    """Remove only the generated Final/ subtree - never data/quests/mercenaries*."""
    assert_not_ours(MANAGED)
    if MANAGED.exists():
        shutil.rmtree(MANAGED)
        print("removed data/Quests/Final/ (all main-quest battle overrides)")
    else:
        print("nothing to revert")
    # Drop data/Quests only if it is genuinely empty - i.e. the mod's own quests are
    # not there. On Windows this is the same folder as data/quests, so never force it.
    if DST_ROOT.exists() and not any(DST_ROOT.iterdir()):
        DST_ROOT.rmdir()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--revert", action="store_true")
    ap.add_argument("--list", action="store_true", help="preview the quests, change nothing")
    ap.add_argument("--scope", default="all", choices=["all", "noHostile"],
                    help="all: every SoulAsset (proven to render, but the test merc "
                         "fought for the garrison). noHostile: skip assets consumed by "
                         "EnableBehavior/SetRelationContext, which is what forced that.")
    args = ap.parse_args()

    if args.revert:
        revert()
        return 0

    souls = merc_souls()
    quests = discover()

    print("merc souls to inject: %d" % len(souls))
    print("main-quest battles found: %d\n" % len(quests))
    print("%-36s %7s %7s %8s" % ("quest", "files", "souls", "battle"))
    for p, files, battle, soulcount in quests:
        print("%-36s %7d %7d %8d" % (p.stem, len(files), soulcount, battle))
    print()

    if args.list:
        print("(--list: nothing written)")
        return 0

    # Clear only the generated subtree. NEVER rmtree DST_ROOT - see MANAGED above.
    assert_not_ours(MANAGED)
    if MANAGED.exists():
        shutil.rmtree(MANAGED)

    cache = {}
    tot_files = tot_lists = tot_guids = tot_skipped = 0

    for p, files, _battle, _sc in quests:
        for f in files:
            cache[f] = read(f)[0]
        skip = hostile_assets(files, cache) if args.scope == "noHostile" else set()
        tot_skipped += len(skip)

        for f in files:
            rel = f.relative_to(SRC_ROOT)
            dst = DST_ROOT / rel
            dst.parent.mkdir(parents=True, exist_ok=True)
            text, encoding = read(f)
            new_text, lists, guids = inject(text, souls, skip)
            with open(dst, "w", encoding=encoding, newline="") as fh:
                fh.write(new_text)
            tot_files += 1
            tot_lists += lists
            tot_guids += guids

    print("scope:              %s" % args.scope)
    print("files written:      %d" % tot_files)
    print("SoulAssets injected:%d" % tot_lists)
    print("guid entries added: %d" % tot_guids)
    if args.scope == "noHostile":
        print("assets skipped (behaviour/relation-driven): %d" % tot_skipped)
    print()
    print("overrides live under data/Quests/ - run PackageModDev.bat")
    print("revert with: python tools/OverrideMainQuestBattles.py --revert")
    return 0


if __name__ == "__main__":
    sys.exit(main())
