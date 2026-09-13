# Generates data/Scripts/mods/mercenaries_gear_data.lua - the GUID -> equipment-slot
# (armour) and GUID -> weapon-class (weapons) lookup the custom gear set needs, plus
# the set of vanilla items that are NEITHER (food, potions, tools, documents...).
#
# There is no runtime bind that reports an item's slot or category, so it has to be
# baked. Source is the extracted vanilla tables under
# references/base_game/Libs/Tables/item/.  Re-run after a game patch:
#     python tools/gen_gear_table.py
#
# EVERY item*.xml is read, not just item.xml. Reading only item.xml left 1120 vanilla
# gear items - all of item__dlc, item__unique, item__rewards, item__horse and
# item__aux - looking exactly like modded items to the wardrobe, which silently
# ignored them. See docs/custom-gear.md.
#
# The third table is what tells a MODDED item apart from a vanilla non-gear one. Both
# are absent from the slot/weapon tables, but they must be treated in opposite ways:
# a loaf of bread in the wardrobe chest is a mistake to ignore, a modded cuirass is a
# piece to wear. "Not in any of the three tables" means "not vanilla" - i.e. modded,
# or from a patch newer than this dump - and the wardrobe accepts those.
import os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TBL  = os.path.join(ROOT, "references", "base_game", "Libs", "Tables", "item")
OUT  = os.path.join(ROOT, "data", "Scripts", "mods", "mercenaries_gear_data.lua")

if not os.path.isdir(TBL):
    raise SystemExit("vanilla item tables not found at %s" % TBL)

# ---- the armour mods -----------------------------------------------------------
# references/armor mods/<n>/ holds one mod's Libs/Tables or Tables tree apiece. Their
# items are already ACCEPTED by the wardrobe (anything in none of the three tables is
# taken to be modded gear), but without a slot they get no layer order and no
# gambeson-under-plate rule - so plate is silently refused. Reading them here is what
# turns "wearable" into "wearable correctly".
MODDIR = os.path.join(ROOT, "references", "armor mods")

def mod_item_files():
    out = []
    if not os.path.isdir(MODDIR):
        return out
    for d in sorted(os.listdir(MODDIR)):
        base = os.path.join(MODDIR, d)
        if not os.path.isdir(base):
            continue
        for dirpath, _dirs, files in os.walk(base):
            for fn in sorted(files):
                if fn.startswith("item") and fn.endswith(".xml"):
                    out.append((d, os.path.join(dirpath, fn)))
    return out

def read(name):
    with open(os.path.join(TBL, name), encoding="ascii", errors="ignore") as f:
        return f.read()

def read_all_items():
    """[(filename, text)] for item.xml plus every item__*.xml, in a stable order."""
    names = sorted(n for n in os.listdir(TBL)
                   if n.startswith("item") and n.endswith(".xml")
                   and not n.endswith(("_category.xml", "_tag.xml", "_ui_sound.xml")))
    print("item tables: %s" % ", ".join(names))
    return [(n, read(n)) for n in names]

# Horse tack is matched by KEYWORD, not by prefix. The prefix table has "Bridle" and
# "Saddle", but the actual clothing names are BasicBridle03_m04, EastSaddle02_m01,
# PaddedCaparison01_mRuthard - none of which START with the mapped word, so all 415
# pieces of tack fell through to slot 0. Slot 0 is a legal, WEARABLE answer, so that
# would have offered the player's mercenaries a saddle to put on.
HORSE_KEYWORD = [
    ("Bridle", 14), ("Chanfron", 14), ("Halter", 14),
    ("Saddle", 16), ("Stirrup", 16),
    ("Shoe", 21),
    ("Caparison", 13), ("Harness", 13), ("Blanket", 13), ("Yoke", 13), ("Plate", 13),
]

def horse_slot(name):
    for word, sid in HORSE_KEYWORD:
        if word.lower() in name.lower():
            return sid
    return 13          # unrecognised tack is still tack: a horse_torso is rejected too

def attrs(tag):
    return dict(re.findall(r'(\w+)="([^"]*)"', tag))

# ---- armor_type name -> equipment slot id -------------------------------------
# equipment_slot.xml lists ArmorTypes for the slots that have layering rules; the
# rest (coats, gloves, boots, collars, hoods, jewellery, horse tack) carry no
# ArmorTypes attribute at all, so those are mapped by hand from the slot names.
slot_of_type = {}
slot_name = {}
for tag in re.findall(r'<EquipmentSlot[^>]*/>', read("equipment_slot.xml")):
    a = attrs(tag)
    sid = int(a["Id"])
    slot_name[sid] = a.get("Name", "")
    for t in (a.get("ArmorTypes") or "").split():
        slot_of_type[t] = sid

MANUAL = {
    "Coat": 7, "Waffenrock": 7, "Habit": 7,
    "Gauntlets": 8, "Gloves": 8,
    "CollarPadded": 22, "CollarMail": 22,
    "Hood": 23,
    "Shoes": 30, "BootsAnkle": 30, "BootsKnee": 30, "F_Shoes": 30,
    "Ring": 18, "Necklace": 19,
    "Belt": 44, "Pouch": 45,
    # Horse tack - deliberately mapped so it can be RECOGNISED and then rejected.
    "Bridle": 14, "Saddle": 16, "Caparison": 13, "HorsePlate": 13,
    "HorsePadded": 13, "HorseShoe": 21,
}
for k, v in MANUAL.items():
    slot_of_type.setdefault(k, v)

armor_types = [attrs(t)["Name"] for t in re.findall(r'<armor_type[^>]*/>', read("armor_type.xml"))]
# Clothing names not covered by the (week-older) armor_type table. Longest-prefix
# match still needs something to hit, so these map straight to a slot.
EXTRA_PREFIX = {
    "BascinetAlberich": 34, "BascinetHans": 34, "BascinetVisorHans": 34,
    "HoodAlbik": 23, "HandWrap": 8,
    "F_Cotehardie": 7, "F_Surcote": 7, "F_Kirtle": 35, "F_Chemise": 35,
    "F_Wreath": 33, "F_HairDecor": 33, "F_Hairnet": 33, "F_Crown": 33,
    "F_Cap": 33, "Wreath": 33, "CollarChain": 22, "WarChanfron": 14,
}
prefixes = sorted(
    [(n, slot_of_type[n]) for n in armor_types if n in slot_of_type] + list(EXTRA_PREFIX.items()),
    key=lambda p: -len(p[0]))

def slot_for(a):
    base = a.get("Clothing") or a.get("Name") or ""
    for name, sid in prefixes:
        if base.startswith(name):
            return sid
    return 0

# ---- parse every item table ---------------------------------------------------
TABLES = read_all_items()

# Every vanilla item id there is, gear or not. Matches the opening tag rather than a
# self-closing one, because an element may carry children (Document does) - the same
# trap that made gen_item_ids.py miss all 15 quest letters.
ALL_VANILLA = set()
for _n, _t in TABLES:
    ALL_VANILLA |= set(re.findall(r'Id="([0-9a-fA-F-]{36})"', _t))

by_slot, by_wclass, quest, aliases = {}, {}, [], []
for fname, text in TABLES:
    is_horse = (fname == "item__horse.xml")
    for tag, body in re.findall(
            r'<(Armor|Helmet|Hood|MeleeWeapon|MissileWeapon|ItemAlias)\b([^>]*)/>', text):
        a = attrs("<x " + body + ">")
        gid = a.get("Id")
        if not gid:
            continue
        isq = a.get("IsQuestItem") == "true"
        if tag == "ItemAlias":
            aliases.append((gid, a.get("SourceItemId"), isq))
            continue
        if tag in ("Armor", "Helmet", "Hood"):
            if is_horse:
                sid = horse_slot(a.get("Clothing") or a.get("Name") or "")
            else:
                sid = slot_for(a)
            by_slot.setdefault(sid, []).append(gid)
        else:
            by_wclass.setdefault(int(a.get("Class", "-1")), []).append(gid)
        if isq:
            quest.append(gid)

# An alias is a relabelled copy of a real item - grade it as its source.
src_slot  = {g: s for s, gs in by_slot.items() for g in gs}
src_wcls  = {g: c for c, gs in by_wclass.items() for g in gs}
for gid, src, isq in aliases:
    if src in src_slot:
        by_slot.setdefault(src_slot[src], []).append(gid)
    elif src in src_wcls:
        by_wclass.setdefault(src_wcls[src], []).append(gid)
    else:
        continue
    if isq:
        quest.append(gid)

# ---- modded gear ---------------------------------------------------------------
# A mod names its Clothing whatever it likes, so the vanilla prefix table alone leaves
# 510 of 2325 pieces unslotted. Three more signals, cheapest and most reliable first:
#
#   IconId  - a mod re-uses the vanilla icon of the piece it is modelled on, so
#             Vavak_rg_chamberlain carries IconId="Coat01_m06_B" and grades as a coat.
#   UIInfo  - same idea one step less precise: ui_in_coif_mail, ui_in_waffenrock.
#   VisorTypeId - only a helmet has a visor.
#
# Both lookups are built FROM THE VANILLA TABLES, so they stay correct across a patch
# instead of being a second hand-maintained list.
icon_slot, ui_slot = {}, {}
for _n, _t in TABLES:
    for _tag, _body in re.findall(r'<(Armor|Helmet|Hood)\b([^>]*)/>', _t):
        _a = attrs("<x " + _body + ">")
        _s = slot_for(_a)
        if not _s:
            continue
        if _a.get("IconId"):
            icon_slot.setdefault(_a["IconId"], _s)
        if _a.get("UIInfo"):
            ui_slot.setdefault(_a["UIInfo"], _s)

# What is left after all four: 27 families, every one of them plain to read. A plume is
# deliberately NOT given a slot - it is a helmet ornament and any real slot would evict
# the helmet; slot 0 is wearable and honest.
MOD_FAMILY = [
    ("Hounskull", 34), ("Legsmailrh", 42), ("NobleCaparison", 13),
    ("Jupon", 7), ("Waffenrorh", 7), ("Knightsurcoat", 7),
    ("Rosary", 19),
    # Ornamental belt daggers, authored as Armor rows rather than weapons.
    ("DaggerRoundel", 44), ("DaggerBollocks", 44), ("DaggerCommon", 44),
]

def mod_slot(a):
    s = slot_for(a)
    if s:
        return s, "clothing"
    ic = a.get("IconId")
    if ic:
        if ic in icon_slot:
            return icon_slot[ic], "icon"
        s = slot_for({"Name": ic})
        if s:
            return s, "icon-prefix"
    ui = a.get("UIInfo")
    if ui and ui in ui_slot:
        return ui_slot[ui], "uiinfo"
    base = a.get("Clothing") or a.get("Name") or ""
    for fam, sid in MOD_FAMILY:
        if base.startswith(fam):
            return sid, "family"
    if a.get("VisorTypeId"):
        return 34, "visor"
    return 0, "unknown"

MOD_FILES = mod_item_files()
mod_ids, mod_by = set(), {}
mod_how = {}
for _mod, _path in MOD_FILES:
    with open(_path, encoding="ascii", errors="ignore") as _f:
        _t = _f.read()
    for _tag, _body in re.findall(
            r'<(Armor|Helmet|Hood|MeleeWeapon|MissileWeapon)\b([^>]*)/>', _t):
        _a = attrs("<x " + _body + ">")
        _gid = _a.get("Id")
        if not _gid or _gid in ALL_VANILLA or _gid in mod_ids:
            continue
        mod_ids.add(_gid)
        if _tag in ("Armor", "Helmet", "Hood"):
            _s, _how = mod_slot(_a)
            by_slot.setdefault(_s, []).append(_gid)
            mod_by.setdefault(_s, 0)
            mod_by[_s] += 1
        else:
            by_wclass.setdefault(int(_a.get("Class", "-1")), []).append(_gid)
            _how = "weapon"
        mod_how[_how] = mod_how.get(_how, 0) + 1
        if _a.get("IsQuestItem") == "true":
            quest.append(_gid)

# Everything vanilla that did not land in a slot or a weapon class.
gear_ids = {g for gs in by_slot.values() for g in gs} | {g for gs in by_wclass.values() for g in gs}
non_gear = (ALL_VANILLA - gear_ids) - mod_ids   # vanilla only, by construction

# ---- emit ---------------------------------------------------------------------
def blobs(guids, per=64):
    flat = "".join(g.replace("-", "") for g in sorted(set(guids)))
    return [flat[i:i + per * 32] for i in range(0, len(flat), per * 32)]

def emit(f, table, comment_of):
    for key in sorted(table):
        chunks = blobs(table[key])
        f.write("    [%d] = {   -- %s (%d)\n" % (key, comment_of(key), len(set(table[key]))))
        for c in chunks:
            f.write('        "%s",\n' % c)
        f.write("    },\n")

wclass_name = {}
for tag in re.findall(r'<(?:MeleeWeaponClass|MissileWeaponClass)[^>]*/>', read("weapon_class.xml")):
    a = attrs(tag)
    wclass_name[int(a["id"])] = a["name"]

with open(OUT, "w", encoding="utf-8", newline="\n") as f:
    f.write("-- GENERATED by tools/gen_gear_table.py - do not edit by hand.\n")
    f.write("-- GUID -> equipment slot / weapon class for every vanilla armour piece and\n")
    f.write("-- weapon. Nothing in the scriptbind reports either, and the custom gear set\n")
    f.write("-- needs both (layer order, the gambeson rule, weapon vs armour). GUIDs are\n")
    f.write("-- stored dashless and concatenated 32 chars apiece; mercenaries_custom_gear.lua\n")
    f.write("-- unpacks them lazily on first use. See docs/custom-gear.md.\n\n")
    f.write("mercenaries.GearSlotBlobs = {\n")
    emit(f, by_slot, lambda k: slot_name.get(k, "unknown"))
    f.write("}\n\nmercenaries.GearWeaponBlobs = {\n")
    emit(f, by_wclass, lambda k: wclass_name.get(k, "unknown"))
    f.write("}\n\n")
    f.write("-- IsQuestItem blocks inventory:CreateItem outright, so a quest piece can never\n")
    f.write("-- be copied onto a merc - it is refused at the wardrobe instead of failing mute.\n")
    f.write("mercenaries.GearQuestBlobs = {\n")
    for c in blobs(quest):
        f.write('    "%s",\n' % c)
    f.write("}\n\n")
    f.write("-- Vanilla items that are NOT gear: food, potions, tools, documents, ingredients.\n")
    f.write("-- The wardrobe needs these to tell a mistake from a modded piece. An item in\n")
    f.write("-- none of the three tables is not vanilla at all, so it is taken to be modded\n")
    f.write("-- armour and worn; one listed here is politely ignored. See docs/custom-gear.md.\n")
    f.write("mercenaries.GearNonGearBlobs = {\n")
    for c in blobs(non_gear):
        f.write('    "%s",\n' % c)
    f.write("}\n\n")
    f.write("-- Clothing-family prefix -> slot, longest first. This is the SAME mapping the\n")
    f.write("-- generator uses on the vanilla Clothing attribute, kept for runtime use on\n")
    f.write("-- items that are not in the blobs at all - i.e. modded ones. ItemManager\n")
    f.write("-- .GetItemName(guid) hands back the item's DB name ('TunicShort05_m09_D'),\n")
    f.write("-- whose leading letters are the clothing family for 98%% of vanilla armour, so\n")
    f.write("-- a modder who named their row conventionally gets a real slot - and with it\n")
    f.write("-- the layer order and the gambeson-under-plate rule, without which plate is\n")
    f.write("-- silently refused. A miss just means slot unknown, which is still wearable.\n")
    f.write("mercenaries.GearNamePrefixSlots = {\n")
    for name, sid in prefixes:
        f.write('    { "%s", %d },\n' % (name, sid))
    f.write("}\n")

print("modded gear: %d item(s) from %d table(s) in references/armor mods/"
      % (len(mod_ids), len(MOD_FILES)))
for _k in sorted(mod_how, key=lambda k: -mod_how[k]):
    print("   %-12s %5d" % (_k, mod_how[_k]))
_unk = mod_by.get(0, 0)
print("   -> %d slotted, %d left unknown (still wearable, just no layer rule)"
      % (len(mod_ids) - _unk, _unk))

n_arm = sum(len(set(v)) for v in by_slot.values())
n_wpn = sum(len(set(v)) for v in by_wclass.values())
print("armour %d (unknown slot: %d), weapons %d, quest %d -> %s"
      % (n_arm, len(set(by_slot.get(0, []))), n_wpn, len(set(quest)), os.path.relpath(OUT, ROOT)))
for s in sorted(by_slot):
    print("   slot %-3d %-20s %d" % (s, slot_name.get(s, "?"), len(set(by_slot[s]))))
for c in sorted(by_wclass):
    print("   wclass %-3d %-20s %d" % (c, wclass_name.get(c, "?"), len(set(by_wclass[c]))))
