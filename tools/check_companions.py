# -*- coding: utf-8 -*-
"""Post-generation checks for the companion roster. Exits non-zero on any failure.

    python tools/check_companions.py
"""

import glob
import io
import os
import re
import sys
import xml.etree.ElementTree as ET

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
os.chdir(ROOT)

from companions_roster import ROSTER                     # noqa: E402
from _item_lookup import load_items                      # noqa: E402

GUID = re.compile(r"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$")
HELMET_PREFIXES = ("Bascinet", "KettleHat", "SkullCap", "Helmet")
BARE_HEADED = ("sigismund", "chamberlain", "martin")

fail = 0


def chk(cond, msg):
    global fail
    print(("OK   " if cond else "FAIL ") + msg)
    if not cond:
        fail += 1


def R(p):
    return io.open(p, encoding="utf-8", errors="surrogateescape").read()


ITEMS = load_items()
BY_GUID = {}
for _n, (_g, _d, _t) in ITEMS.items():
    BY_GUID[_g.lower()] = _n


def preset_items(xml_text, preset_name):
    m = re.search(r'clothing_preset_name="%s"[^>]*>(.*?)</clothing_preset>'
                  % re.escape(preset_name), xml_text, re.S)
    if not m:
        return None
    return [BY_GUID.get(g.lower(), "?" + g)
            for g in re.findall(r"<Guid>([0-9a-fA-F\-]+)</Guid>", m.group(1))]


def main():
    files = [
        "data/libs/tables/rpg/soul__mercenaries.xml",
        "data/libs/tables/skald/skald_character__mercenaries.xml",
        "data/libs/tables/skald/skald_character2profession__mercenaries.xml",
        "data/libs/tables/skald/skald_character2role__mercenaries.xml",
        "data/libs/Storm/appearance/mercenariesappearance.xml",
        "data/libs/Storm/equipment/mercenariesequipment.xml",
        "data/libs/Storm/roles/mercenariesroles.xml",
        "data/libs/tables/item/clothing_preset__mercenaries.xml",
        "data/libs/tables/item/weapon_preset__mercenaries.xml",
        "data/libs/tables/item/InventoryPreset__mercenaries.xml",
    ]
    for r in ("kutnohorsko", "trosecko"):
        b = "data/Quests/mercenaries/%s/mercenaries_background_quest" % r
        files += [b + ".xml", b + "/hire_dialog.xml", b + "/quartermaster_dialog.xml"]
    files += sorted(glob.glob("localization/*_xml.xml"))

    bad = []
    for f in files:
        try:
            ET.parse(f)
        except Exception as exc:
            bad.append((f, str(exc)[:60]))
    chk(not bad, "all %d XML files well-formed%s"
        % (len(files), "" if not bad else "  %s" % bad[:2]))

    # --- souls ------------------------------------------------------------
    soul = R("data/libs/tables/rpg/soul__mercenaries.xml")
    ids = re.findall(r'soul_id="([^"]+)"', soul)
    chk(all(GUID.match(g) for g in ids), "every soul_id is a well-formed guid")
    dupes = sorted(set(g for g in ids if ids.count(g) > 1))
    chk(not dupes, "no duplicate soul_id  %s" % dupes[:3])

    lua = R("data/Scripts/mods/mercenaries.lua")
    blk = re.search(r"mercenaries\.CustomCompanionsData = \{(.*?)\n\}", lua, re.S).group(1)
    pairs = re.findall(r'\[(\d+)\] = \{ guid = "([^"]+)"', blk)
    chk(sorted(int(i) for i, _ in pairs) == list(range(1, 45)),
        "CustomCompanionsData holds ccid 1-44 (%d)" % len(pairs))
    declared = set(ids)
    kubenka = "74db1d52-7360-4ed3-b716-f6a53f47f2f9"
    orphan = [g for _, g in pairs if g not in declared and g != kubenka]
    chk(not orphan, "every companion guid has a soul row  %s" % orphan[:3])

    # --- helmets ----------------------------------------------------------
    cp = R("data/libs/tables/item/clothing_preset__mercenaries.xml")
    gen = re.search(r"generated companions.*?end generated companions", cp, re.S)
    visored = sorted(set(
        BY_GUID.get(g.lower(), "")
        for g in re.findall(r"<Guid>([0-9a-fA-F\-]+)</Guid>", gen.group(0))
        if BY_GUID.get(g.lower(), "").startswith("BascinetVisor")))
    chk(not visored, "no closable visor in any built companion preset  %s" % visored)

    vcl = R("references/Libs/Tables/item/clothing_preset.xml")
    by_key = dict((c["key"], c) for c in ROSTER)

    def worn_by(key):
        """Every item name a companion ends up in, built preset or vanilla one."""
        cc = by_key[key]
        name = ("merc_cc_" + key) if cc["cloth"][0] == "build" else cc["cloth"][1]
        return preset_items(cp, name) or preset_items(vcl, name)

    for key in BARE_HEADED:
        names = worn_by(key)
        chk(names is not None, "%s resolves to a clothing preset" % key)
        if names:
            helms = [n for n in names if n.startswith(HELMET_PREFIXES)]
            chk(not helms, "%s wears no helmet  %s" % (key, helms))

    inv = R("data/libs/tables/item/InventoryPreset__mercenaries.xml")
    chk('<ClothingPresetRef Name="UC_Aulitz" />' in inv,
        "aulitz uses the helmetless UC_Aulitz preset")

    # --- Martin: no armour at all, and immortal because of it ---------------
    martin = worn_by("martin")
    chk(martin is not None, "martin resolves to a clothing preset")
    if martin:
        armoured = [n for n in martin if ITEMS.get(n, ("", 0, ""))[1] >= 50]
        chk(not armoured, "martin wears nothing with real armour value  %s" % armoured)
        chk(sum(ITEMS.get(n, ("", 0, ""))[1] for n in martin) < 60,
            "martin's whole outfit is cosmetic-tier (%d)"
            % sum(ITEMS.get(n, ("", 0, ""))[1] for n in martin))
    m = re.search(r'soul_name="soul_merc_martin"', soul)
    row = soul[soul.rfind("<soul", 0, m.start()):soul.index("/>", m.start())]
    chk('soul_vip_class_id="12"' in row,
        "martin's soul carries vip class 12 (immortal, cannot be knocked out)")
    others = re.findall(r'<soul[^>]*soul_name="soul_merc_(\w+)"[^>]*'
                        r'soul_vip_class_id="(\d+)"', soul)
    wrong = [(k, v) for k, v in others
             if k in by_key and int(v) != by_key[k].get("vip", 16)]
    chk(not wrong, "every other companion keeps its declared vip class  %s" % wrong[:3])

    # --- both hiring menus, both regions ----------------------------------
    want = set(str(i) for i in range(1, 45))
    for r in ("kutnohorsko", "trosecko"):
        b = "data/Quests/mercenaries/%s/mercenaries_background_quest" % r
        q = R(b + ".xml")
        for dlg, role in (("hire_dialog", "role_mercenary_provider"),
                          ("quartermaster_dialog", "role_mercenary_quartermaster")):
            d = R(b + "/" + dlg + ".xml")
            ports = set(re.findall(r'<Port Name="hire_c(\d+)" Direction="Out"', d))
            trig = set(re.findall(r'<Triggers><Port Name="hire_c(\d+)" /></Triggers>', d))
            edges = set(re.findall(r'From="%s\.hire_c(\d+)"' % dlg, q))
            chk(ports == want and trig == want and edges == want,
                "%s/%s: ports, triggers and quest nodes all 1-44" % (r, dlg))
            roles = set(re.findall(
                r'<Response Role="(role_mercenary_\w+)"><Text StringName="merc_provider_', d))
            chk(roles == {role}, "%s/%s: spoken by %s  %s" % (r, dlg, role, roles))
            cats = re.findall(r'<Sequence EndType="Decision" Name="seq_cat_(\w+)">', d)
            chk(len(cats) == 5 and len(set(cats)) == 5,
                "%s/%s: 5 unique category menus" % (r, dlg))
            seqs = re.findall(r'Name="seq_hire_(\w+)"', d)
            chk(len(seqs) == 44 and len(set(seqs)) == 44,
                "%s/%s: 44 unique hire sequences (%d)" % (r, dlg, len(seqs)))
            keys = set(re.findall(
                r'StringName="(ui_mercenary_[a-z_0-9]+|merc_henry_[a-z_0-9]+'
                r'|merc_provider_[a-z_0-9]+)"', d))
            have = set(re.findall(r"<Cell>([a-zA-Z_0-9]+)</Cell>",
                                  R("localization/English_xml.xml")))
            miss = sorted(k for k in keys if k not in have)
            chk(not miss, "%s/%s: every dialog string localised  %s" % (r, dlg, miss[:4]))

    # --- the hero rules ---------------------------------------------------
    spawn = R("data/Scripts/mods/mercenaries_spawning.lua")
    chk('"SpawnedFriend_hero_"' in spawn,
        "companions spawn under the SpawnedFriend_ prefix")
    util = R("data/Scripts/mods/mercenaries_util.lua")
    chk("function mercenaries:IsHeroName" in util and "function mercenaries:IsHero" in util,
        "IsHeroName / IsHero exist")
    chk("MercenaryCustomCompanion" in util, "the legacy prefix is still recognised")
    for path, what in (
            ("data/Scripts/mods/mercenaries_equipment.lua", "equipment skips heroes"),
            ("data/Scripts/mods/mercenaries_custom_gear.lua", "custom uniform skips heroes"),
            ("data/Scripts/mods/mercenaries_camp.lua", "camp chat skips heroes"),
            ("data/Scripts/mods/mercenaries.lua", "RequestBark skips heroes"),
            ("data/Scripts/mods/mercenaries_target_selection.lua",
             "target selection skips heroes")):
        chk("IsHero" in R(path), what)

    print("\n%d check(s) failed" % fail)
    return 1 if fail else 0


if __name__ == "__main__":
    sys.exit(main())
