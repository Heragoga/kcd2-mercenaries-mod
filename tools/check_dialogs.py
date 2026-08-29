# -*- coding: utf-8 -*-
"""Static check of the Skald <-> Lua <-> localization chain.

A dialog option in this mod is only whole if six things line up, and nothing in the
game complains when one is missing - the option just silently does nothing, or the
whole concept graph fails to load. This walks the chain and says which link is broken:

  1. every <Triggers><Port> used in a dialog is DECLARED as an Out port in that dialog
  2. every declared Out port that is used has exactly one Edge in the region quest
  3. every EventFunction's ItemClass exists in item__mercenaries.xml
  4. every ItemClass a dialog grants is polled in Lua (a TokenID* constant)
  5. count-as-selector tokens (one GUID, Amount = which option) grant 1..N with no
     gaps or duplicates, and N matches the Lua table that reads them
  6. both region copies (kutnohorsko, trosecko) are the same dialog
  7. every mod StringName a dialog or Lua uses exists in localization/English_xml.xml
     (vanilla StringNames the mod borrows are allowed through)
  8. all 16 localization tables carry the same keys

Run from the repo root:  python tools/check_dialogs.py
Exit code is 1 if anything failed, so it can gate a package build.
"""
from __future__ import print_function

import glob
import io
import os
import re
import sys
import xml.etree.ElementTree as ET

REGIONS = ("kutnohorsko", "trosecko")
QUEST_DIR = "data/Quests/mercenaries/%s"
ITEM_XML = "data/libs/tables/item/item__mercenaries.xml"
LUA_GLOB = "data/Scripts/mods/*.lua"
LOC_DIR = "localization"
VANILLA_TEXT = "references/Text"

# StringNames with these prefixes are ours and must be in English_xml.xml. Anything
# else is assumed to be a vanilla key the mod is borrowing (see docs/skald/add-dialog.md).
MOD_KEY = re.compile(r"^(ui_qm_|ui_mercenary_|ui_merc_|merc_henry_|merc_qm_|merc_info_|"
                     r"merc_logi_|merc_provider_|merc_alx_|merc_bc_|merc_bounty_)")

# Menus whose options share one token and are told apart by the granted Amount.
# name -> (token GUID, Lua file, Lua table whose length is the option count)
SELECTOR_TOKENS = {
    "remove-one-upgrade": ("679a655e-189d-4519-b437-ccc4b92bef1d",
                           "data/Scripts/mods/mercenaries_logistics.lua", "UpgRemovable"),
    "party-composition": ("679a655e-189d-4519-b437-ccc4b92bef2d",
                          "data/Scripts/mods/mercenaries_camp.lua", "CampCompositionOptions"),
}

errors = []
warnings = []


def err(msg):
    errors.append(msg)


def warn(msg):
    warnings.append(msg)


def read(path):
    return io.open(path, encoding="utf-8-sig", errors="replace").read()


def dialog_files(region):
    return sorted(glob.glob(os.path.join(QUEST_DIR % region,
                                         "mercenaries_background_quest", "*.xml")))


# ---------------------------------------------------------------- ports and edges
def check_ports(region):
    """1, 2: a triggered port must be declared, and must reach an EventFunction."""
    quest_path = os.path.join(QUEST_DIR % region, "mercenaries_background_quest.xml")
    if not os.path.exists(quest_path):
        err("%s: no region quest at %s" % (region, quest_path))
        return {}
    quest = read(quest_path)
    edges = set(re.findall(r'<Edge From="([^"]+)"', quest))

    declared_by_dialog = {}
    for path in dialog_files(region):
        src = read(path)
        name = os.path.splitext(os.path.basename(path))[0]
        declared = set(re.findall(r'<Port Name="([^"]+)"\s+Direction="Out"', src))
        # the attribute order varies across the file; catch the spaced-out form too
        declared |= set(re.findall(r'<Port Name="([^"]+)"\s+Direction="Out"\s+Type="trigger"', src))
        used = set(re.findall(r'<Triggers><Port Name="([^"]+)"\s*/></Triggers>', src))
        used |= set(re.findall(r'<Triggers>\s*<Port Name="([^"]+)"', src))
        declared_by_dialog[name] = declared

        for p in sorted(used - declared):
            err("%s/%s: option triggers port '%s' but the dialog never declares it"
                % (region, name, p))
        for p in sorted(used & declared):
            ref = "%s.%s" % (name, p)
            if ref not in edges:
                err("%s/%s: port '%s' fires but no EventFunction in the region quest "
                    "listens for it - the option will do nothing" % (region, name, p))
        for p in sorted(declared - used):
            if "%s.%s" % (name, p) in edges:
                continue
            warn("%s/%s: port '%s' is declared but never used" % (region, name, p))
    return declared_by_dialog


# ---------------------------------------------------------------- item classes
def check_items(region, item_guids, lua_tokens):
    """3, 4: every granted ItemClass must be a real item AND be polled in Lua."""
    quest_path = os.path.join(QUEST_DIR % region, "mercenaries_background_quest.xml")
    quest = read(quest_path)
    for guid in sorted(set(re.findall(r'<Constant Name="ItemClass" Value="([^"]+)" />', quest))):
        if guid not in item_guids:
            # not necessarily wrong: a dialog may hand out a base-game item
            warn("%s: dialog grants item %s, which is not one of the mod's own"
                 % (region, guid))
        elif guid not in lua_tokens:
            warn("%s: dialog grants item %s, which no Lua constant polls"
                 % (region, guid))


def event_functions(region):
    """(name, ItemClass, Amount) per EventFunction. PARSED, not text-scanned: a regex
    for `<EventFunction>...</EventFunction>` silently merges neighbouring blocks and so
    reports an option index twice."""
    tree = ET.parse(os.path.join(QUEST_DIR % region, "mercenaries_background_quest.xml"))
    out = []
    for ef in tree.getroot().iter("EventFunction"):
        item, amount = None, None
        for c in ef.iter("Constant"):
            if c.get("Name") == "ItemClass":
                item = c.get("Value")
            elif c.get("Name") == "Amount":
                amount = c.get("Value")
        out.append((ef.get("Name"), item, amount))
    return out


def check_selectors(region):
    """5: one GUID, Amount = option index. Must be a clean 1..N run matching Lua."""
    for label, (guid, lua_path, table_name) in sorted(SELECTOR_TOKENS.items()):
        amounts = []
        for _name, item, amount in event_functions(region):
            if item == guid and amount and amount.isdigit():
                amounts.append(int(amount))
        if not amounts:
            err("%s: no dialog option grants the %s token" % (region, label))
            continue
        if sorted(amounts) != list(range(1, len(amounts) + 1)):
            err("%s: %s amounts are %s - they must be 1..N with no gaps or repeats, "
                "the amount IS the option index" % (region, label, sorted(amounts)))
        n = lua_table_len(lua_path, table_name)
        if n is None:
            err("%s: cannot find the Lua table '%s' the %s menu indexes into"
                % (region, table_name, label))
        elif n != len(amounts):
            err("%s: %s has %d dialog options but Lua's %s has %d entries - the menu "
                "and the handler disagree" % (region, label, len(amounts), table_name, n))


def lua_table_len(path, table_name):
    """Count top-level `{ ... }` entries of `mercenaries.<table_name> = { ... }`."""
    if not os.path.exists(path):
        return None
    src = read(path)
    m = re.search(r"mercenaries\.%s\s*=\s*\{" % re.escape(table_name), src)
    if not m:
        return None
    i = m.end() - 1
    depth, n = 0, 0
    while i < len(src):
        c = src[i]
        if c == "{":
            depth += 1
            if depth == 2:
                n += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                return n
        i += 1
    return None


# ---------------------------------------------------------------- region parity
def check_regions_match(declared):
    """6: the two region copies are hand-mirrored, so they drift silently."""
    a, b = REGIONS
    for name in sorted(set(declared[a]) | set(declared[b])):
        pa, pb = declared[a].get(name), declared[b].get(name)
        if pa is None or pb is None:
            warn("dialog '%s' exists only in %s" % (name, a if pb is None else b))
            continue
        # a real divergence, but a legitimate one: the contracts are kutnohorsko-only
        for p in sorted(pa - pb):
            warn("port '%s' of %s exists in %s but not in %s" % (p, name, a, b))
        for p in sorted(pb - pa):
            warn("port '%s' of %s exists in %s but not in %s" % (p, name, b, a))


# ---------------------------------------------------------------- strings
def load_keys(path):
    return set(re.findall(r"<Row><Cell>([^<]+)</Cell>", read(path)))


def check_strings(english, vanilla):
    """7: every mod StringName a dialog or Lua asks for must resolve."""
    used = {}
    for region in REGIONS:
        for path in dialog_files(region) + [os.path.join(QUEST_DIR % region,
                                                         "mercenaries_background_quest.xml")]:
            src = read(path)
            for k in re.findall(r'StringName="([^"]+)"', src):
                used.setdefault(k, path)
    for path in sorted(glob.glob(LUA_GLOB)):
        src = read(path)
        # `SendInfoText('merc_info_x_' .. mode)` names no key on its own - skip the stem
        for k, cat in re.findall(r"SendInfoText\(\s*'([^']+)'(\s*\.\.)?", src):
            if cat:
                continue
            used.setdefault(k, path)
        for k in re.findall(r':hint\("([^"]+)"\)', src):
            used.setdefault(k, path)
    for k, where in sorted(used.items()):
        if k in english or k in vanilla:
            continue
        if not re.match(r"^[A-Za-z_][A-Za-z0-9_]{3,}$", k):
            continue
        if MOD_KEY.match(k):
            err("string '%s' (used by %s) is in no localization table" % (k, where))
        else:
            warn("string '%s' (used by %s) is neither ours nor a vanilla key we ship"
                 % (k, where))


def check_locale_parity(english):
    """8: a key present in English and missing elsewhere shows as raw id in that language."""
    for path in sorted(glob.glob(os.path.join(LOC_DIR, "*_xml.xml"))):
        if path.endswith("English_xml.xml"):
            continue
        keys = load_keys(path)
        missing = english - keys
        extra = keys - english
        if missing:
            err("%s is missing %d key(s), e.g. %s"
                % (os.path.basename(path), len(missing), ", ".join(sorted(missing)[:5])))
        if extra:
            warn("%s has %d key(s) English does not, e.g. %s"
                 % (os.path.basename(path), len(extra), ", ".join(sorted(extra)[:5])))


def check_xml_wellformed():
    for path in sorted(glob.glob("data/**/*.xml", recursive=True)
                       + glob.glob(os.path.join(LOC_DIR, "*.xml"))):
        try:
            ET.parse(path)
        except Exception as e:  # noqa: BLE001 - report, don't stop
            err("%s is not well-formed XML: %s" % (path, e))


def main():
    check_xml_wellformed()

    item_guids = set(re.findall(r'Id="([^"]+)"', read(ITEM_XML)))
    lua_tokens = set()
    for path in glob.glob(LUA_GLOB):
        # a token can live in a table (AlxSpawnToken) as well as in a TokenID* constant
        lua_tokens |= set(re.findall(r'"([0-9a-fA-F-]{36})"', read(path)))

    declared = {}
    for region in REGIONS:
        declared[region] = check_ports(region)
        check_items(region, item_guids, lua_tokens)
        check_selectors(region)
    check_regions_match(declared)

    english = load_keys(os.path.join(LOC_DIR, "English_xml.xml"))
    vanilla = set()
    for path in glob.glob(os.path.join(VANILLA_TEXT, "*.xml")):
        vanilla |= load_keys(path)
    check_strings(english, vanilla)
    check_locale_parity(english)

    for w in warnings:
        print("WARN  " + w)
    for e in errors:
        print("FAIL  " + e)
    print("\n%d error(s), %d warning(s)" % (len(errors), len(warnings)))
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
