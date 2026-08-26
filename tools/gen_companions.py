# -*- coding: utf-8 -*-
"""Turn tools/companions_roster.py into every file a custom companion needs.

Idempotent: each target file gets one sentinel-delimited block that is rewritten in
place on every run, so editing the roster and re-running is the whole workflow.

    python tools/gen_companions.py            # write
    python tools/gen_companions.py --check    # report only, touch nothing

The hire dialog is the exception - its whole custom-companion section is regenerated,
existing 18 included, because they are sorted into the same category sub-menus.
"""

import io
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)

from companions_roster import ROSTER, EXISTING, CATEGORIES, SOUL_PREFIX  # noqa: E402
from _item_lookup import load_items                                      # noqa: E402

VANILLA = os.path.join(ROOT, "references", "Libs")
CHECK = "--check" in sys.argv

BEGIN = "generated companions - tools/gen_companions.py - do not edit by hand"
END = "end generated companions"

MERC_BRAIN = "e2a51ce4-449f-4a2e-83b9-c098c5b118cd"
HIRE_TOKEN = "679a655e-189d-4519-b437-ccc4b92be48d"

# reference_cloning_vanilla_npcs: a body_type the mod does not already ship can pair
# with a unique_assets index that cannot travel, and the NPC spawns but never renders.
SAFE_BODY = {0, 2, 3, 4}

# soul_vip_class is a bitfield: 1 pickpocket, 2 attack, 4 immortality,
# 8 unconsciousness, 16 loot. Only the combinations named in
# references/Libs/Tables/rpg/soul_vip_class.xml are declared, so stick to those.
# 16 (loot_protection) is the default - the player should not be able to strip his
# own men. A roster entry can override it with vip=; 12 is
# immortality_and_unconsciousness_protection, what the quartermaster and Aleksej use.
DEFAULT_VIP = 16
VALID_VIP = {0, 1, 2, 3, 4, 8, 12, 13, 15, 16, 23, 31}

report = []


def note(msg):
    report.append(msg)


# --------------------------------------------------------------------------- io

def read(path):
    return io.open(os.path.join(ROOT, path), encoding="utf-8", errors="surrogateescape").read()


def write(path, text):
    if CHECK:
        return
    io.open(os.path.join(ROOT, path), "w", encoding="utf-8",
            errors="surrogateescape", newline="").write(text)


def splice(path, block, before, comment=("<!-- %s -->", "<!-- %s -->")):
    """Replace (or insert) the generated block in path, on its own lines before `before`."""
    src = read(path)
    body = comment[0] % BEGIN + "\n" + block.rstrip("\n") + "\n" + comment[1] % END + "\n"
    pat = re.compile(re.escape(comment[0] % BEGIN) + r".*?" + re.escape(comment[1] % END) + r"\n?",
                     re.S)
    if pat.search(src):
        out = pat.sub(lambda _m: body, src, count=1)
        note("%-62s block replaced" % path)
    else:
        # Back up to the start of the closing tag's own line, so the block lands
        # between whole lines rather than inside the indent of the tag.
        idx = src.rindex(before)
        idx = src.rfind("\n", 0, idx) + 1
        out = src[:idx] + body + src[idx:]
        note("%-62s block inserted" % path)
    write(path, out)


# ------------------------------------------------------------------ source data

ITEMS = load_items()                                  # name -> (guid, defence, tag)
BY_GUID = {}
for _n, (_g, _d, _t) in ITEMS.items():
    BY_GUID[_g.lower()] = (_n, _d)


def item(name):
    if name not in ITEMS:
        raise SystemExit("unknown item name in roster: %s" % name)
    return ITEMS[name][0]


def load_vanilla_characters():
    txt = io.open(os.path.join(VANILLA, "Tables", "skald", "skald_character.xml"),
                  encoding="utf-8", errors="surrogateescape").read()
    out = {}
    for m in re.finditer(r"<skald_character\s([^>]*?)/>", txt):
        attrs = dict(re.findall(r'(\w+)="([^"]*)"', m.group(1)))
        nm = attrs.get("skald_character_name")
        if nm:
            out[nm] = attrs
    return out


def load_vanilla_clothing():
    txt = io.open(os.path.join(VANILLA, "Tables", "item", "clothing_preset.xml"),
                  encoding="utf-8", errors="surrogateescape").read()
    out = {}
    for m in re.finditer(r'<clothing_preset\s([^>]*?)>(.*?)</clothing_preset>', txt, re.S):
        nm = re.search(r'clothing_preset_name="([^"]*)"', m.group(1))
        if nm:
            out[nm.group(1)] = re.findall(r"<Guid>([0-9a-fA-F\-]+)</Guid>", m.group(2))
    return out


CHARS = load_vanilla_characters()
CLOTHING = load_vanilla_clothing()


# ------------------------------------------------------------------- per-entry

def soul_guid(cc):
    # The existing run is c098c5b1 + 1801..1817 - four digits, not five. Get this
    # wrong and the last group is 13 hex characters and the guid is not a guid.
    return SOUL_PREFIX + "%04d" % (1800 + cc["ccid"] - 1)


def soul_name(cc):
    return "soul_merc_" + cc["key"]


def char_name(cc):
    return "char_mercenary_" + cc["key"]


def built_clothing_name(cc):
    return "merc_cc_" + cc["key"]


def built_clothing_guid(cc):
    return "6d657263-0c0c-4b00-9000-%012x" % cc["ccid"]


def built_weapon_name(cc):
    return "merc_cc_wpn_" + cc["key"]


def built_weapon_guid(cc):
    return "6d657263-0c0d-4b00-9000-%012x" % cc["ccid"]


def clothing_preset_of(cc):
    kind = cc["cloth"][0]
    return cc["cloth"][1] if kind == "vanilla" else built_clothing_name(cc)


def weapon_preset_of(cc):
    kind = cc["weap"][0]
    return cc["weap"][1] if kind == "vanilla" else built_weapon_name(cc)


def resolve_built_clothing(cc):
    """The final GUID list for a built clothing preset, and its total defence."""
    _kind, base, drop, add = cc["cloth"]
    guids = list(CLOTHING.get(base, [])) if base else []
    if base and base not in CLOTHING:
        raise SystemExit("unknown base clothing preset in roster: %s" % base)
    dropped = set(x.lower() for x in (item(n) for n in drop))
    guids = [g for g in guids if g.lower() not in dropped]
    have = set(g.lower() for g in guids)
    for n in add:
        g = item(n)
        if g.lower() not in have:
            guids.append(g)
            have.add(g.lower())
    total = sum(BY_GUID.get(g.lower(), ("?", 0))[1] for g in guids)
    return guids, total


# ------------------------------------------------------------------ generators

def gen_souls():
    rows = []
    for cc in ROSTER:
        rows.append(
            '\t\t<soul brain_id="%s" combat_level="1" digestion_multiplier="0" '
            'factionName="mercenariesFaction" initial_clothing_dirt="0" '
            'skald_character_name="%s" social_class_id="3" soul_archetype_id="0" '
            'soul_id="%s" soul_name="%s" soul_vip_class_id="%d" xp_multiplier="0" />'
            % (MERC_BRAIN, char_name(cc), soul_guid(cc), soul_name(cc),
               cc.get("vip", DEFAULT_VIP)))
    splice("data/libs/tables/rpg/soul__mercenaries.xml", "\n".join(rows), "\t</souls>")


STRING_FIELDS = ["description_string_name", "history_string_name", "other_string_name",
                 "physical_description_string_name", "skald_character_full_name_string_name",
                 "ui_name_string_name"]


def gen_characters():
    rows = []
    for cc in ROSTER:
        src = CHARS.get(cc["char"])
        if not src:
            raise SystemExit("unknown vanilla skald_character in roster: %s" % cc["char"])
        body = int(src.get("body_type", "4") or 4)
        if body not in SAFE_BODY:
            note("  body_type %d on %s is not one the mod ships - using 4" % (body, cc["key"]))
            body = 4
        attrs = [
            ('age', src.get("age", "2")),
            ('body_type', str(body)),
            ('gender', src.get("gender", "0")),
            ('image1', "false"), ('image2', "false"), ('image3', "false"), ('image4', "false"),
            ('skald_character_name', char_name(cc)),
            ('unique_assets', ""),
            ('voice_categories', src.get("voice_categories", "generic christian")),
            ('voice_id', src.get("voice_id", "106")),
        ]
        for f in STRING_FIELDS:
            v = src.get(f, "")
            if v:
                attrs.append((f, v))
        attrs.sort(key=lambda kv: kv[0])
        rows.append("\t<skald_character " +
                    " ".join('%s="%s"' % kv for kv in attrs) + " />")
    splice("data/libs/tables/skald/skald_character__mercenaries.xml",
           "\n".join(rows), "\t</skald_characters>")

    rows = ['\t<skald_character2profession profession_name="pocestny" skald_character_name="%s" />'
            % char_name(cc) for cc in ROSTER]
    splice("data/libs/tables/skald/skald_character2profession__mercenaries.xml",
           "\n".join(rows), "\t</skald_character2professions>")

    rows = []
    for role in ("role_mercenary_test", "role_mercenary_test2"):
        for cc in ROSTER:
            rows.append('\t<skald_character2role role_id="%s" skald_character_id="%s" />'
                        % (role, char_name(cc)))
    splice("data/libs/tables/skald/skald_character2role__mercenaries.xml",
           "\n".join(rows), "\t</skald_character2roles>")


APP_ORDER = ["Head", "Hair", "Body", "Beard", "Underwear"]


def gen_appearance():
    rows = []
    for cc in ROSTER:
        ops = []
        for k in APP_ORDER:
            if cc["app"].get(k):
                ops.append('                <set%s name="%s" />' % (k, cc["app"][k]))
        rows.append(
            '        <rule name="appearance_mercenary_%s">\n'
            '            <selectors>\n'
            '                <hasName Name="%s" />\n'
            '            </selectors>\n'
            '            <operations>\n%s\n'
            '            </operations>\n'
            '        </rule>' % (cc["key"], soul_name(cc), "\n".join(ops)))
    splice("data/libs/Storm/appearance/mercenariesappearance.xml",
           "\n\n".join(rows), "</rules>")


def gen_equipment():
    rows = []
    for cc in ROSTER:
        rows.append(
            '        <rule name="inventory_mercenary_%s" Mode="and">\n'
            '            <selectors>\n'
            '                <hasName name="%s" />\n'
            '            </selectors>\n'
            '            <operations>\n'
            '                <setInventory preset="inventory_merc_%s" />\n'
            '            </operations>\n'
            '        </rule>' % (cc["key"], soul_name(cc), cc["key"]))
    splice("data/libs/Storm/equipment/mercenariesequipment.xml",
           "\n\n".join(rows), "</rules>")


def gen_roles():
    rows = []
    for cc in ROSTER:
        rows.append(
            '    <rule name="mercenary_%s_role">\n'
            '      <selectors>\n'
            '        <hasName name="%s" />\n'
            '      </selectors>\n'
            '      <operations>\n'
            '        <addRole name="role_mercenary_test" />\n'
            '        <addRole name="role_mercenary_test2" />\n'
            '      </operations>\n'
            '    </rule>' % (cc["key"], soul_name(cc)))
    splice("data/libs/Storm/roles/mercenariesroles.xml", "\n\n".join(rows), "</rules>")


def gen_inventory_presets():
    rows = []
    for cc in ROSTER:
        rows.append(
            '        <InventoryPreset Name="inventory_merc_%s" Health="1">\n'
            '            <ClothingPresetRef Name="%s" />\n'
            '            <WeaponPresetRef Name="%s" />\n'
            '            <InventoryPresetRef Name="%s" />\n'
            '        </InventoryPreset>'
            % (cc["key"], clothing_preset_of(cc), weapon_preset_of(cc), cc["pockets"]))
    splice("data/libs/tables/item/InventoryPreset__mercenaries.xml",
           "\n\n".join(rows), "</InventoryPresets>")


def gen_clothing_presets():
    rows = []
    for cc in ROSTER:
        if cc["cloth"][0] != "build":
            continue
        guids, total = resolve_built_clothing(cc)
        note("  %-14s clothing %4d def, %2d piece(s)" % (cc["key"], total, len(guids)))
        body = "\n".join("\t\t\t\t<Guid>%s</Guid>" % g for g in guids)
        rows.append(
            '\t\t<!-- %s. %s -->\n'
            '\t\t<clothing_preset clothing_preset_id="%s" clothing_preset_name="%s" '
            'gender="Male" prefers_hood_on="false">\n'
            '\t\t\t<Items>\n%s\n\t\t\t</Items>\n'
            '\t\t</clothing_preset>'
            % (cc["name"], cc["note"], built_clothing_guid(cc), built_clothing_name(cc), body))
    splice("data/libs/tables/item/clothing_preset__mercenaries.xml",
           "\n\n".join(rows), "</clothing_presets>")


def gen_weapon_presets():
    rows = []
    for cc in ROSTER:
        if cc["weap"][0] != "build":
            continue
        body = "\n".join('\t\t\t<weapon_preset_item item_class_id="%s" />' % item(n)
                         for n in cc["weap"][1])
        rows.append(
            '\t\t<!-- %s -->\n'
            '\t\t<weapon_preset weapon_preset_id="%s" weapon_preset_name="%s">\n%s\n'
            '\t\t</weapon_preset>'
            % (cc["name"], built_weapon_guid(cc), built_weapon_name(cc), body))
    splice("data/libs/tables/item/weapon_preset__mercenaries.xml",
           "\n\n".join(rows), "</weapon_presets>")


def gen_lua():
    path = "data/Scripts/mods/mercenaries.lua"
    src = read(path)
    rows = ['    [%d] = { guid = "%s", cost = %d, name = "%s" },'
            % (cc["ccid"], soul_guid(cc), cc["cost"], cc["name"]) for cc in ROSTER]
    rows[-1] = rows[-1].rstrip(",")
    block = ("    -- BEGIN " + BEGIN + "\n" + "\n".join(rows) + "\n    -- " + END)
    pat = re.compile(r"    -- BEGIN " + re.escape(BEGIN) + r".*?    -- " + re.escape(END), re.S)
    if pat.search(src):
        out = pat.sub(lambda _m: block, src, count=1)
        note("%-62s block replaced" % path)
    else:
        m = re.search(r'(mercenaries\.CustomCompanionsData = \{.*?name = "Hans Capon" \})',
                      src, re.S)
        if not m:
            raise SystemExit("could not find the tail of CustomCompanionsData")
        out = src[:m.end(1)] + ",\n" + block + src[m.end(1):]
        note("%-62s block inserted" % path)
    write(path, out)


QUESTS = ["data/Quests/mercenaries/kutnohorsko/mercenaries_background_quest.xml",
          "data/Quests/mercenaries/trosecko/mercenaries_background_quest.xml"]


def reward_node(name, y, amount, port_source, port_id):
    return ('                <EventFunction Name="%s" PositionY="%d" '
            'PositionX="800" MethodName="wh::entitymodule::CreatePlayerReward" '
            'DeclaringType="wh::entitymodule">\n'
            '                    <Constant Name="ItemClass" Value="%s" />\n'
            '                    <Constant Name="Amount" Value="%d" />\n'
            '                    <Constant Name="ShowUINotification" Value="false" />\n'
            '                    <Edge From="%s.hire_c%d" To="Exec" />\n'
            '                </EventFunction>'
            % (name, y, HIRE_TOKEN, amount, port_source, port_id))


# Both hiring dialogues have their own port set and their own reward nodes: the
# provider's (execute_recruit_<key>) and the quartermaster's (exec_qm_hire_c<id>).
QUEST_NODE_SETS = [
    ("hire_dialog", '<EventFunction Name="execute_recruit_capon"',
     lambda cc: "execute_recruit_" + cc["key"], 3800),
    ("quartermaster_dialog", '<EventFunction Name="exec_qm_hire_c18"',
     lambda cc: "exec_qm_hire_c%d" % cc["ccid"], 4000),
]


def gen_quests():
    for q in QUESTS:
        src = read(q)
        # Drop every previously generated block first, so the anchors below are the
        # original ones however many times this has run.
        src = re.sub(r"\n\s*<!-- " + re.escape(BEGIN) + r" -->.*?<!-- " + re.escape(END) +
                     r" -->", "", src, flags=re.S)
        for source, anchor, namer, y0 in QUEST_NODE_SETS:
            rows = [reward_node(namer(cc), y0 + i * 200, cc["ccid"], source, cc["ccid"])
                    for i, cc in enumerate(ROSTER)]
            i = src.index(anchor)
            j = src.index("</EventFunction>", i) + len("</EventFunction>")
            body = ("\n\n                <!-- %s -->\n%s\n                <!-- %s -->"
                    % (BEGIN, "\n\n".join(rows), END))
            src = src[:j] + body + src[j:]
        write(q, src)
        note("%-62s recruit nodes written (both dialogues)" % q)


# ------------------------------------------------------------------ hire dialog

# Both hiring menus, in both regions. They differ only in which role speaks the
# provider's half of each line.
DIALOGS = []
for _region in ("kutnohorsko", "trosecko"):
    _base = "data/Quests/mercenaries/%s/mercenaries_background_quest/" % _region
    DIALOGS.append((_base + "hire_dialog.xml", "role_mercenary_provider"))
    DIALOGS.append((_base + "quartermaster_dialog.xml", "role_mercenary_quartermaster"))


def all_companions():
    """(ccid, key, category) for all 44, existing first."""
    out = [(c[0], c[1], c[2]) for c in EXISTING]
    out += [(cc["ccid"], cc["key"], cc["cat"]) for cc in ROSTER]
    return out


def build_menu(role, indent=32):
    """The five category sub-menus plus a back option, as one Sequences body."""
    everyone = all_companions()
    I = " " * indent

    def hire_seq(ccid, key):
        p = " " * (indent + 12)
        return (
            '%s<Sequence EndType="EndDialogue" Name="seq_hire_%s">\n'
            '%s    <UiPrompt StringName="ui_mercenary_custom_%s" />\n'
            '%s    <Triggers><Port Name="hire_c%d" /></Triggers>\n'
            '%s    <Elements>\n'
            '%s        <Response Role="HENRY"><Text StringName="merc_henry_%s" /></Response>\n'
            '%s        <Response Role="%s"><Text StringName="merc_provider_%s" /></Response>\n'
            '%s    </Elements>\n'
            '%s</Sequence>' % (p, key, p, key, p, ccid, p, p, key, p, role, key, p, p))

    cats = []
    for cat, _label in CATEGORIES:
        members = sorted((cid, k) for cid, k, c in everyone if c == cat)
        inner = "\n\n".join(hire_seq(cid, k) for cid, k in members)
        cats.append(
            '%s<Sequence EndType="Decision" Name="seq_cat_%s">\n'
            '%s    <UiPrompt StringName="ui_mercenary_cat_%s" />\n'
            '%s    <Elements>\n'
            '%s        <Response Role="HENRY"><Text StringName="merc_henry_cat_%s" /></Response>\n'
            '%s        <Response Role="%s">'
            '<Text StringName="merc_provider_cat_%s" /></Response>\n'
            '%s    </Elements>\n'
            '%s    <Decision Name="dec_cat_%s">\n'
            '%s        <Sequences>\n%s\n\n'
            '%s            <Sequence EndType="GoTo" GoToDecision="dec_custom" '
            'Name="seq_cat_%s_back">\n'
            '%s                <UiPrompt StringName="ui_mercenary_custom_cancel" />\n'
            '%s                <Elements><Response Role="HENRY">'
            '<Text StringName="merc_henry_custom_cancel" /></Response></Elements>\n'
            '%s            </Sequence>\n'
            '%s        </Sequences>\n'
            '%s    </Decision>\n'
            '%s</Sequence>'
            % (I, cat, I, cat, I, I, cat, I, role, cat, I, I, cat, I, inner,
               I, cat, I, I, I, I, I, I))
        note("  menu %-8s %d companion(s)" % (cat, len(members)))

    back = ('%s<Sequence EndType="GoTo" GoToDecision="dec_hire_type" Name="seq_custom_cancel">\n'
            '%s    <UiPrompt StringName="ui_mercenary_custom_cancel" />\n'
            '%s    <Elements>\n'
            '%s        <Response Role="HENRY">\n'
            '%s            <Text StringName="merc_henry_custom_cancel" />\n'
            '%s        </Response>\n'
            '%s    </Elements>\n'
            '%s</Sequence>' % (I, I, I, I, I, I, I, I))
    return "\n\n".join(cats) + "\n\n" + back


def gen_dialog():
    for d, role in DIALOGS:
        src = read(d)
        sequences = build_menu(role)

        # Ports. Strip any previously generated ones first, so a repeat run does not
        # stack a second set on top of them.
        src = re.sub(r'\n\s*<Port Name="hire_c(?:19|[2-9]\d|\d{3})" [^/]*/>', "", src)
        last_port = '<Port Name="hire_c18" Direction="Out" Type="trigger" />'
        k = src.index(last_port) + len(last_port)
        ports = "".join('\n                <Port Name="hire_c%d" Direction="Out" Type="trigger" />'
                        % cc["ccid"] for cc in ROSTER)
        src = src[:k] + ports + src[k:]

        # The whole dec_custom ELEMENT, replaced against anchors that sit outside it.
        #
        # Not a non-greedy regex on </Sequences></Decision>: the category sub-menus are
        # themselves Decisions, so the first such close is the one inside the FIRST
        # category, and matching it appends a second copy of every later category
        # instead of replacing them. seq_type_cancel is the next sibling of the Sequence
        # that owns dec_custom, appears exactly once in each dialogue and is never
        # generated, so it is a stable end marker whatever state the file is in. Its
        # GoToDecision differs between the two dialogues, so match the name only.
        start = src.index('<Decision Name="dec_custom">')
        tail = src.index('Name="seq_type_cancel">')
        close = src.rindex("</Sequence>", start, tail)      # closes seq_type_custom
        close = src.rfind("\n", 0, close) + 1
        body = ('<Decision Name="dec_custom">\n'
                '%s    <Sequences>\n\n%s\n\n'
                '%s    </Sequences>\n'
                '%s</Decision>\n' % (" " * 40, sequences, " " * 40, " " * 40))
        src = src[:start] + body + src[close:]
        write(d, src)
        note("%-62s menu rebuilt (%s)" % (d, role))


# ---------------------------------------------------------------- localisation

LOC_DIR = "localization"


def loc_rows():
    rows = []
    for cat, label in CATEGORIES:
        rows.append(("ui_mercenary_cat_" + cat, label + "."))
        rows.append(("merc_henry_cat_" + cat, "Tell me about " + label[0].lower() + label[1:] + "."))
        rows.append(("merc_provider_cat_" + cat, "Here's who I can reach."))
    for cc in ROSTER:
        rows.append(("ui_mercenary_custom_" + cc["key"],
                     "%s (%d groschen)." % (cc["name"], cc["cost"])))
        rows.append(("merc_henry_" + cc["key"], "I'll take %s." % cc["name"]))
        rows.append(("merc_provider_" + cc["key"], "I'll send word. He'll come."))
    return rows


def gen_loc():
    rows = loc_rows()
    for fn in sorted(os.listdir(os.path.join(ROOT, LOC_DIR))):
        if not fn.endswith("_xml.xml"):
            continue
        path = os.path.join(LOC_DIR, fn)
        src = read(path)
        body = "\n".join(
            "  <Row><Cell>%s</Cell><Cell>%s</Cell><Cell>%s</Cell></Row>" % (k, v, v)
            for k, v in rows)
        splice(path, body, "</Table>")


# ---------------------------------------------------------------------- checks

def sanity():
    seen = {}
    for cc in ROSTER:
        for field, val in (("ccid", cc["ccid"]), ("key", cc["key"]), ("soul", soul_guid(cc))):
            if (field, val) in seen:
                raise SystemExit("duplicate %s: %r" % (field, val))
            seen[(field, val)] = True
        if cc["ccid"] < 19:
            raise SystemExit("ccid %d collides with an existing companion" % cc["ccid"])
        if cc["cat"] not in dict(CATEGORIES):
            raise SystemExit("unknown category %r on %s" % (cc["cat"], cc["key"]))
        vip = cc.get("vip", DEFAULT_VIP)
        if vip not in VALID_VIP:
            raise SystemExit("vip class %r on %s is not declared in soul_vip_class.xml"
                             % (vip, cc["key"]))
        if vip != DEFAULT_VIP:
            note("  %-14s soul_vip_class %d (not the default %d)"
                 % (cc["key"], vip, DEFAULT_VIP))
        if cc["cloth"][0] == "vanilla" and cc["cloth"][1] not in CLOTHING:
            raise SystemExit("clothing preset not in vanilla: %s" % cc["cloth"][1])
        if cc["cloth"][0] == "build":
            resolve_built_clothing(cc)
        if cc["weap"][0] == "build":
            for n in cc["weap"][1]:
                item(n)
    note("roster: %d new companion(s), ccid %d-%d"
         % (len(ROSTER), min(c["ccid"] for c in ROSTER), max(c["ccid"] for c in ROSTER)))


def main():
    sanity()
    gen_souls()
    gen_characters()
    gen_appearance()
    gen_equipment()
    gen_roles()
    gen_clothing_presets()
    gen_weapon_presets()
    gen_inventory_presets()
    gen_lua()
    gen_quests()
    gen_dialog()
    gen_loc()
    print("\n".join(report))
    print("\n%s" % ("checked, nothing written" if CHECK else "written"))


if __name__ == "__main__":
    main()
