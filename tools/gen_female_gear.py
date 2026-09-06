"""Generate the female mercenaries' wardrobe: the medium kit with the headgear taken out.

Female mercs are their own category and do NOT follow the squad's outfit style (see
docs/female-mercenaries.md) - they have one pool of their own, and it is built here rather
than written by hand so it stays in step with the medium tier it is derived from.

WHY A SEPARATE POOL AND NOT A RUNTIME STRIP. The first attempt dressed them normally and then
called Human.UnequipItemInSlot on the head slots. It ran - kcd.log showed the sweep touching
all ten women, with a live ent.human and no refusal - and the helmets stayed on, four passes
over 2.8 s notwithstanding. GetArmor read 0 either side, so it could not even say whether the
unequip had landed. A preset that never contained a helmet cannot leave one on.

WHAT IT DOES. Reads the ten style-1 ("Generic Mercs") MEDIUM presets out of
clothing_preset__mercenaries.xml, drops every item that belongs to a head slot - 34 helmet,
33 cap, 32 padded coif, 31 coif, 23 hood - and writes the remainder back as ten new presets
between generated markers in the same file.

SLOT RESOLUTION READS THE MOD'S OWN TABLE, mercenaries_gear_data.lua, rather than re-deriving
slots from the vanilla item tables. gen_gear_table.py already does that derivation properly -
over every item*.xml AND the armour mods in references/ - so the wardrobe's own authority is
what decides what a helmet is here. Re-run gen_gear_table.py after a game patch or an
armour-mod change.

That is worth doing rather than parsing the tables again because parsing them naively is a trap
this script already fell into once: the first version matched only <Armor> elements, and the
helmet in every one of these presets (713a4f57-647f-4ab6-8c6e-ad189f6f5eee) is a <Helmet>. It
therefore dropped nothing but the mail coifs, left every helmet on, and - because the GUID
turned up in no <Armor> tag - led to the wrong conclusion that it was a modded item. It is
vanilla KettleHat03_m02_B3. Armour stats live on <Armor>, <Hood>, <Helmet> and
<QuickSlotContainer>; see build_stats.

The armour cost is REPORTED, not compensated. docs/outfits.md is explicit that every preset in
a tier is solved to the same budget, and taking the helmet off breaks that by design - a
bare-headed merc is worth less in a fight than a helmeted one, and padding the body to hide
that would be a lie about what the player is buying.

Usage:
    python tools/gen_female_gear.py
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TBL = os.path.join(ROOT, 'references', 'base_game', 'Libs', 'Tables', 'item')
GEAR = os.path.join(ROOT, 'data', 'Scripts', 'mods', 'mercenaries_gear_data.lua')
PRESETS = os.path.join(ROOT, 'data', 'libs', 'tables', 'item',
                      'clothing_preset__mercenaries.xml')

BEGIN = '\t\t<!-- BEGIN generated female wardrobe (tools/gen_female_gear.py) -->'
END = '\t\t<!-- END generated female wardrobe -->'

# The ten style-1 medium presets, from mercenaries.Outfits[1].medium.
SOURCE = ['6d657263-0102-4b00-9000-00000000000' + c for c in '123456789a']
# New ids in the same family. Style "0f" is not a real style, which is the point: nothing in
# mercenaries.Outfits can reach these, only mercenaries_female.lua.
DEST = ['6d657263-0f01-4b00-9000-00000000000' + c for c in '123456789a']

HEAD_SLOTS = {34, 33, 32, 31, 23}


def attrs(tag):
    return dict(re.findall(r'([A-Za-z_]\w*)="([^"]*)"', tag))


def build_slot_map():
    """GUID -> equipment slot id, out of the mod's own generated wardrobe table.

    GearSlotBlobs stores each slot's members as dashless 32-character GUIDs concatenated into
    a few long strings, so unpacking is: join the strings, cut every 32 characters.
    """
    with open(GEAR, encoding='utf-8') as f:
        lua = f.read()
    start = lua.find('mercenaries.GearSlotBlobs = {')
    if start < 0:
        raise SystemExit('GearSlotBlobs not found in %s' % GEAR)
    body = lua[start:]
    out = {}
    for m in re.finditer(r'\[(\d+)\] = \{(.*?)\n    \},', body, re.S):
        sid = int(m.group(1))
        blob = ''.join(re.findall(r'"([0-9a-f]*)"', m.group(2)))
        for i in range(0, len(blob), 32):
            h = blob[i:i + 32]
            if len(h) == 32:
                out['%s-%s-%s-%s-%s' % (h[:8], h[8:12], h[12:16], h[16:20], h[20:])] = sid
    return out


def build_stats():
    """GUID -> (name, stab+slash+smash), for the printed report.

    FOUR element types carry armour stats, not one: <Armor> (1916 of them), <Hood> (130),
    <Helmet> (106) and <QuickSlotContainer> (7). An earlier version read only <Armor>, so every
    helmet and hood in the game came back "unknown" - which made the headgear this script exists
    to remove look like it had no armour value at all, and understated the cost of a bare head
    by more than half. It also led to the wrong conclusion that the bascinet in these presets
    was a mod item; it is vanilla KettleHat03_m02_B3, just under a <Helmet> tag.
    """
    stats = {}
    if not os.path.isdir(TBL):
        return stats
    names = sorted(n for n in os.listdir(TBL)
                   if n.startswith('item') and n.endswith('.xml')
                   and not n.endswith(('_category.xml', '_tag.xml', '_ui_sound.xml')))
    for fn in names:
        with open(os.path.join(TBL, fn), encoding='ascii', errors='ignore') as f:
            text = f.read()
        for tag in re.findall(r'<(?:Armor|Hood|Helmet|QuickSlotContainer)[^>]*/>', text):
            a = attrs(tag)
            if not a.get('Id') or 'DefenseStab' not in a:
                continue
            stats[a['Id']] = (a.get('Name', ''),
                              float(a.get('DefenseStab', 0) or 0)
                              + float(a.get('DefenseSlash', 0) or 0)
                              + float(a.get('DefenseSmash', 0) or 0))
    return stats


def main():
    slot = build_slot_map()
    stats = build_stats()
    print('wardrobe slot table: %d items (%d with vanilla armour stats)'
          % (len(slot), len(stats)))

    with open(PRESETS, encoding='utf-8-sig') as f:
        xml = f.read()

    blocks = []
    kept_total = dropped_total = 0.0
    unknown_drops = 0
    for i, (src, dst) in enumerate(zip(SOURCE, DEST), 1):
        pat = (r'<clothing_preset[^>]*clothing_preset_id="%s"[^>]*>(.*?)</clothing_preset>'
               % re.escape(src))
        m = re.search(pat, xml, re.S)
        if not m:
            print('  source preset %s NOT FOUND' % src)
            return 1
        guids = re.findall(r'<Guid>\s*([0-9a-fA-F-]{36})\s*</Guid>', m.group(1))
        keep, drop = [], []
        for g in guids:
            (drop if slot.get(g, 0) in HEAD_SLOTS else keep).append(g)
        if not drop:
            print('  %-2d WARNING: no headgear recognised in %s - nothing dropped' % (i, src))
        kept_total += sum(stats.get(g, ('', 0))[1] for g in keep)
        dropped_total += sum(stats.get(g, ('', 0))[1] for g in drop)
        unknown_drops += sum(1 for g in drop if g not in stats)
        shown = ', '.join('%s[slot %d]' % (stats.get(g, (g[:8] + '... (mod item)', 0))[0],
                                           slot.get(g, 0)) for g in drop)
        print('  %-2d %2d items -> %2d   dropped: %s' % (i, len(guids), len(keep), shown or 'NOTHING'))

        items = '\n'.join('\t\t\t\t<Guid>%s</Guid>' % g for g in keep)
        blocks.append(
            '\t\t<clothing_preset clothing_preset_id="%s" '
            'clothing_preset_name="clothing_preset_mercenary_female_%d" gender="Male" '
            'prefers_hood_on="false" social_class_id="3">\n'
            '\t\t\t<Items>\n%s\n\t\t\t</Items>\n'
            '\t\t</clothing_preset>' % (dst, i, items))

    n = len(SOURCE)
    caveat = ''
    if unknown_drops:
        caveat = ('\n\t\t     (%d of the dropped pieces are armour-mod items with no stats in\n'
                  '\t\t     references/base_game, so the real gap is larger than that.)'
                  % unknown_drops)
    note = ('\t\t<!-- The medium wardrobe with the headgear removed - see the script.\n'
            '\t\t     Mean armour left %.0f, against %.0f for the same presets with their\n'
            '\t\t     headgear on: a bare-headed merc is worth about %.0f less than a man of\n'
            '\t\t     her tier, and that is the price of showing her face.%s -->\n'
            % (kept_total / n, (kept_total + dropped_total) / n, dropped_total / n, caveat))
    body = BEGIN + '\n' + note + '\n'.join(blocks) + '\n' + END

    if BEGIN in xml:
        xml = re.sub(re.escape(BEGIN) + r'.*?' + re.escape(END), lambda _: body, xml, flags=re.S)
    else:
        # The closing tag's indentation is NOT a tab in this file - it is four spaces - and an
        # earlier version anchored on '\t</clothing_presets>', matched nothing, and wrote the
        # file back unchanged while printing "10 female presets written". Match whatever
        # whitespace is actually there, and refuse to write if the anchor is missing rather
        # than reporting success over a no-op.
        m = re.search(r'\n([ \t]*)</clothing_presets>', xml)
        if not m:
            print('ERROR: no </clothing_presets> to insert before - nothing written')
            return 1
        xml = xml[:m.start()] + '\n' + body + m.group(0) + xml[m.end():]

    if xml.count(BEGIN) != 1 or xml.count(END) != 1:
        print('ERROR: generated block not exactly once - nothing written')
        return 1
    for dst in DEST:
        if dst not in xml:
            print('ERROR: %s missing from the result - nothing written' % dst)
            return 1

    with open(PRESETS, 'w', encoding='utf-8-sig', newline='') as f:
        f.write(xml)

    print('\n%d female presets written to %s' % (n, os.path.relpath(PRESETS, ROOT)))
    print('mean armour %.0f, was %.0f with headgear (-%.0f)%s'
          % (kept_total / n, (kept_total + dropped_total) / n, dropped_total / n,
             '; %d dropped piece(s) had no stats available' % unknown_drops
             if unknown_drops else ''))
    return 0


if __name__ == '__main__':
    sys.exit(main())
