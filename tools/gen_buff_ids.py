# -*- coding: utf-8 -*-
"""Generate mercenaries_buff_ids.lua from buff__mercenaries.xml.

Same reason as gen_item_ids.py: the uninstall purge must take EVERY buff this mod
defines off Henry, not just the five status effects the script tracks by name. A
buff id left on a soul is a dangling table reference once the mod is gone.

Run: python tools/gen_buff_ids.py
"""
import io
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
SRC = os.path.join(ROOT, "data", "libs", "tables", "rpg", "buff__mercenaries.xml")
DST = os.path.join(ROOT, "data", "Scripts", "mods", "mercenaries_buff_ids.lua")


def main():
    with io.open(SRC, encoding="ascii", errors="replace") as f:
        src = f.read()

    rows, seen = [], set()
    for el in re.findall(r"<buff\b.*?/>", src, re.S):
        def attr(a):
            m = re.search(r'\b%s="([^"]*)"' % a, el)
            return m.group(1) if m else ""
        gid = attr("buff_id")
        if not gid or gid in seen:
            continue
        seen.add(gid)
        rows.append({
            "id": gid,
            "name": attr("buff_name") or "(unnamed)",
            "persistent": attr("is_persistent").lower() == "true",
        })

    out = [
        "-- GENERATED FILE - DO NOT EDIT BY HAND.",
        "-- Source: data/libs/tables/rpg/buff__mercenaries.xml",
        "-- Regenerate: python tools/gen_buff_ids.py",
        "--",
        "-- Every buff this mod defines. merc_purge_buffs takes the lot off Henry, because",
        "-- a buff id on a soul is a dangling table reference once the mod is gone. The",
        "-- persistent flag is the one that matters for a SAVE: a non-persistent buff dies",
        "-- with the session anyway, so it is recorded but cannot be the load-time cost.",
        "",
        "mercenaries.ModBuffIds = {",
    ]
    for r in rows:
        out.append('    { id = "%s", name = "%s", persistent = %s },'
                   % (r["id"], r["name"], "true" if r["persistent"] else "false"))
    out.append("}")
    out.append("")

    with io.open(DST, "w", encoding="utf-8", newline="\r\n") as f:
        f.write("\n".join(out))

    npers = sum(1 for r in rows if r["persistent"])
    print("wrote %s" % DST)
    print("  %d buff(s), %d persistent" % (len(rows), npers))


if __name__ == "__main__":
    main()
