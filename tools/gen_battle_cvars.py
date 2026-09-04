# -*- coding: utf-8 -*-
"""Generate mercenaries_battle_cvars.lua from the game's own battle CVarOverride files.

Libs/Tables/CVarOverride.xml binds a GameContext to a cfg under Config/CVarOverrides/.
Entering one is what writes `Loading config file '...utokNaMalesov_battle.cfg'` to kcd.log.
HasScriptContext cannot see those contexts (measured 2026-09-04), so the mod detects the
battle by the NUMBERS those files push instead - which means it needs to know them.

The values are per sys_spec: each file is a series of [<spec>] blocks, with [default]
first. Run: python tools/gen_battle_cvars.py
"""
import io
import os
import re
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
DST = os.path.join(ROOT, "data", "Scripts", "mods", "mercenaries_battle_cvars.lua")

GAME = r"C:\Program Files (x86)\Steam\steamapps\common\KingdomComeDeliverance2"
PAK = os.path.join(GAME, "Engine", "Engine.pak")
FILES = [
    ("utokNaMalesov_battle", "Config/CVarOverrides/utokNaMalesov_battle.cfg"),
    ("Battle",               "Config/CVarOverrides/Battle.cfg"),
]


def parse(text):
    """-> {spec: {cvar: value}}. Blocks are [default], [1], [2], ..."""
    out, spec = {}, "default"
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith(("--", ";", "#")):
            continue
        m = re.match(r"^\[([^\]]+)\]$", line)
        if m:
            spec = m.group(1).strip()
            out.setdefault(spec, {})
            continue
        m = re.match(r"^([A-Za-z_]\w*)\s*=\s*(.+)$", line)
        if m:
            out.setdefault(spec, {})[m.group(1)] = m.group(2).strip()
    return out


def main():
    z = zipfile.ZipFile(PAK)
    parsed = {}
    for name, path in FILES:
        parsed[name] = parse(z.read(path).decode("utf-8", "replace"))

    canon = parsed["utokNaMalesov_battle"]
    other = parsed["Battle"]

    # Stable listing order: first appearance in the canonical file.
    order, seen = [], set()
    for spec in ["default"] + sorted(k for k in canon if k != "default"):
        for cv in canon.get(spec, {}):
            if cv not in seen:
                seen.add(cv)
                order.append(cv)

    # Cvars whose value is identical in both battle files, per spec: those are the safest
    # detection anchors, since any battle raises them, not just Malesov.
    out = [
        "-- GENERATED FILE - DO NOT EDIT BY HAND.",
        "-- Source: Config/CVarOverrides/{utokNaMalesov_battle,Battle}.cfg in Engine.pak",
        "-- Regenerate: python tools/gen_battle_cvars.py",
        "--",
        "-- What the engine pushes when a scripted battle starts, per sys_spec. The mod reads",
        "-- these to KNOW a battle is running (HasScriptContext cannot see the GameContext on",
        "-- this build) and merc_battlecvar applies them by hand, one at a time, to find out",
        "-- which of them is what makes mercenaries vanish in a scripted battle.",
        "",
        "mercenaries.BattleCvarOrder = {",
    ]
    for cv in order:
        out.append('    "%s",' % cv)
    out.append("}")
    out.append("")
    out.append("-- [spec][cvar] = value, as a STRING: several are multi-number lists.")
    out.append("mercenaries.BattleCvarBySpec = {")
    for spec in ["default"] + sorted((k for k in canon if k != "default"),
                                     key=lambda x: (not x.isdigit(), int(x) if x.isdigit() else x)):
        rows = canon[spec]
        if not rows:
            continue
        out.append('    ["%s"] = {' % spec)
        for cv in order:
            if cv in rows:
                same = other.get(spec, {}).get(cv) == rows[cv]
                out.append('        ["%s"] = "%s",%s' % (cv, rows[cv], "" if same else "   -- differs in Battle.cfg"))
        out.append("    },")
    out.append("}")
    out.append("")

    # Detection anchors. Three cvars, chosen because ground truth from kcd.log at sys_spec 1
    # shows each MOVES when a battle cfg loads (25->40, 1->2, 15->20) and none is owned by
    # mercenaries_lodboost. e_MergedMeshesLodRatio is deliberately excluded: it reads 5 both
    # in and out of battle at that spec, so it can never discriminate. The accepted set is
    # the UNION across both battle files, since Malesov and the generic Battle.cfg disagree
    # by one value and either one means "a scripted battle is running".
    anchors = ["wh_e_HLodClusterSwitchingDistanceMin",
               "e_MergedMeshesInstanceDist",
               "e_MergedMeshesViewDistRatio"]
    out.append("-- [spec][cvar] = { accepted values }. ALL of these matching means a battle cfg")
    out.append("-- is in force. No session baseline is involved, so it cannot be fooled by being")
    out.append("-- sampled mid-battle - which is exactly what defeated the first attempt.")
    out.append("mercenaries.BattleCvarAnchors = {")
    for spec in sorted(canon, key=lambda x: (not x.isdigit(), int(x) if x.isdigit() else x)):
        vals = {}
        for cv in anchors:
            got = []
            for src in (canon, other):
                v = src.get(spec, {}).get(cv)
                if v is not None and v not in got:
                    got.append(v)
            if got:
                vals[cv] = got
        if len(vals) < 2:
            continue
        out.append('    ["%s"] = {' % spec)
        for cv in anchors:
            if cv in vals:
                out.append('        ["%s"] = { %s },' % (cv, ", ".join('"%s"' % v for v in vals[cv])))
        out.append("    },")
    out.append("}")
    out.append("")

    with io.open(DST, "w", encoding="utf-8", newline="\r\n") as f:
        f.write("\n".join(out))
    print("wrote %s" % DST)
    print("  %d cvar(s), specs: %s" % (len(order), ", ".join(sorted(canon))))


if __name__ == "__main__":
    main()
