"""Generate data/Scripts/mods/mercenaries_item_ids.lua from the mod's item table.

The uninstall/audit commands need to know EVERY item class this mod adds, so they can
count them in the player's inventory and strip them before a save that will be loaded
without the mod. The authoritative list is data/libs/tables/item/item__mercenaries.xml -
not the Lua constants, which only name the ~95 tokens the script itself references.

Re-run after adding or removing rows in item__mercenaries.xml:

    python tools/gen_item_ids.py

Never hand-edit the generated Lua file.
"""

import io
import os
import re

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(REPO, "data", "libs", "tables", "item", "item__mercenaries.xml")
DST = os.path.join(REPO, "data", "Scripts", "mods", "mercenaries_item_ids.lua")

# Rows and comments in document order, so each row can inherit the comment above it.
# The element pattern must accept BOTH self-closing rows and rows with children: every
# <Document> (the quest letters, which are the items most likely to be sitting in a
# player's inventory for good) wraps its text, so a "/>"-only pattern silently missed
# all 15 of them - the opposite of what this list is for.
TOKEN = re.compile(
    r'<!--(?P<comment>.*?)-->'
    r'|<(?P<tag>[A-Za-z]+)\s(?P<attrs>[^>]*?)/?>',
    re.S,
)
ATTR = re.compile(r'(\w+)="([^"]*)"')


def clean(s):
    s = " ".join(s.split())
    # Lua long-bracket safety and comment safety: the note is emitted inside a "--" line
    # and a quoted string, so drop the characters that could break either.
    return s.replace("\\", "/").replace('"', "'").replace("\n", " ")


def main():
    text = io.open(SRC, encoding="utf-8-sig").read()

    rows = []
    note = ""
    for m in TOKEN.finditer(text):
        if m.group("comment") is not None:
            note = clean(m.group("comment"))
            continue
        attrs = dict(ATTR.findall(m.group("attrs")))
        iid = attrs.get("Id")
        if not iid:
            continue
        rows.append({
            "id": iid,
            "tag": m.group("tag"),
            "name": attrs.get("Name", ""),
            "note": note,
        })

    seen = set()
    unique = []
    for r in rows:
        if r["id"] in seen:
            print("WARNING duplicate Id, skipping: %s" % r["id"])
            continue
        seen.add(r["id"])
        unique.append(r)

    out = []
    out.append("-- GENERATED FILE - DO NOT EDIT BY HAND.")
    out.append("-- Source: data/libs/tables/item/item__mercenaries.xml")
    out.append("-- Regenerate: python tools/gen_item_ids.py")
    out.append("--")
    out.append("-- Every item class this mod defines. The uninstall/audit commands need the")
    out.append("-- WHOLE list, not just the tokens the script happens to reference by name:")
    out.append("-- any of these left in a save is a broken class reference once the mod is")
    out.append("-- gone. See mercenaries_commands.lua (merc_items / merc_purge_*).")
    out.append("")
    out.append("mercenaries.ModItemIds = {")
    last = None
    for r in unique:
        if r["note"] != last:
            out.append("    -- " + (r["note"] or "(uncommented)"))
            last = r["note"]
        out.append('    { id = "%s", tag = "%s", name = "%s" },' % (r["id"], r["tag"], r["name"]))
    out.append("}")
    out.append("")
    prefixes = sorted({r["id"].split("-")[0] for r in unique})

    with io.open(DST, "w", encoding="utf-8", newline="\r\n") as f:
        f.write("\n".join(out))

    print("wrote %s" % DST)
    print("  %d item class(es), prefixes: %s" % (len(unique), ", ".join(prefixes)))


if __name__ == "__main__":
    main()
