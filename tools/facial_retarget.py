"""Give custom dialogue lines a face by retargeting vanilla lipsync clips.

KCD2 binds a facial animation to a line purely by name: the clip is called
<voiceAbbrev>_<StringName> and sits at the same relative path as the line's .ogg,
under Animations/humans/facials/dialog instead of Localization/dialog.

A .dba stores that name as a u16 length-prefixed string with no name hash, so a
vanilla single-clip .dba can be re-pointed at one of our StringNames byte-wise.
male.chrparams / female.chrparams already wildcard-load Animations\\humans\\facials\\*.dba.

See docs/lipsync.md.

Usage:
    python tools/facial_retarget.py                 # regenerate the merc_qm_* set
    python tools/facial_retarget.py --rebuild-index # rescan the game paks first
"""
import glob
import json
import os
import re
import struct
import sys
import zipfile

GAME = r'C:\Program Files\Steam\steamapps\common\KingdomComeDeliverance2'
REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

INDEX = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'facial_donors.json')
OUT_DIR = os.path.join(REPO, 'data', 'Animations', 'humans', 'facials', 'dialog')

# where our voice .ogg files land (PackageMod.bat), mirrored under the facials root
VOICE_FOLDER = 'mercenaries_background_quest'
CAF_ROOT = 'animations/humans/facials/dialog/' + VOICE_FOLDER

# quartermaster: skald_character voice_id 243 -> voice.xml abbreviation
VOICE = 'rlaz'
PREFIX = 'merc_qm_'

CPS = 14.5  # english speech, characters per second
SAME_VOICE_SLACK = 0.4  # seconds of length error we will trade for the right actor

CAF_PATH = re.compile(rb'animations/humans/facials/[ -~]{10,180}?\.caf')


# ---------------------------------------------------------------- donor index

def ogg_duration(raw):
    i = raw.find(b'\x01vorbis')
    if i < 0:
        return None
    rate = struct.unpack_from('<I', raw, i + 12)[0]
    j = raw.rfind(b'OggS')
    if j < 0 or rate == 0:
        return None
    return struct.unpack_from('<q', raw, j + 6)[0] / float(rate)


def build_index():
    """Every single-clip facial .dba, with the duration of its original line."""
    donors = []
    for pak in sorted(glob.glob(os.path.join(GAME, 'Data', 'Facials', 'Facials_*.pak'))):
        z = zipfile.ZipFile(pak)
        for info in z.infolist():
            if not info.filename.endswith('.dba') or info.file_size > 60000:
                continue
            paths = CAF_PATH.findall(z.read(info.filename))
            if len(paths) == 1:
                leaf = paths[0].decode().split('/')[-1][:-4]
                donors.append({'pak': os.path.basename(pak), 'dba': info.filename,
                               'leaf': leaf, 'voice': leaf.split('_')[0]})

    voice_index = {}
    for pak in sorted(glob.glob(os.path.join(GAME, 'Localization', 'english-part*.pak')) +
                      glob.glob(os.path.join(GAME, 'Localization', 'IPL_english.pak'))):
        z = zipfile.ZipFile(pak)
        for n in z.namelist():
            if n.lower().endswith('.ogg'):
                voice_index.setdefault(os.path.basename(n)[:-4].lower(), (pak, n))

    opened, out = {}, []
    for d in donors:
        ref = voice_index.get(d['leaf'].lower())
        if not ref:
            continue
        pak, entry = ref
        if pak not in opened:
            opened[pak] = zipfile.ZipFile(pak)
        try:
            dur = ogg_duration(opened[pak].read(entry))
        except Exception:
            dur = None
        if dur:
            d['dur'] = round(dur, 3)
            out.append(d)

    out.sort(key=lambda x: x['dur'])
    json.dump(out, open(INDEX, 'w'), indent=1)
    return out


def load_index(rebuild=False):
    if rebuild or not os.path.exists(INDEX):
        print('scanning game paks for donor clips (a few minutes)...')
        return build_index()
    return json.load(open(INDEX))


# ---------------------------------------------------------------- dba rewrite

def retarget(src, new_path):
    """Re-point a single-clip .dba at new_path, keeping the chunk table valid."""
    m = CAF_PATH.search(src)
    if not m:
        raise ValueError('no facial clip path in dba')
    off, end = m.start(), m.end()
    old_len = struct.unpack_from('<H', src, off - 2)[0]
    if old_len != end - off:
        raise ValueError('length field %d does not match string %d' % (old_len, end - off))

    new = new_path.encode('ascii')
    delta = len(new) - old_len
    out = bytearray(src[:off - 2] + struct.pack('<H', len(new)) + new + src[end:])

    if delta:
        ver, count, tbl = struct.unpack_from('<III', src, 4)
        struct.pack_into('<III', out, 4, ver, count, tbl + delta if tbl > off else tbl)
        p = tbl + delta if tbl > off else tbl
        q = tbl
        for _ in range(count):
            ct, cv, cid, csize, coff = struct.unpack_from('<HHIII', src, q)
            q += 16
            if coff <= off < coff + csize:
                csize += delta
            if coff > off:
                coff += delta
            struct.pack_into('<HHIII', out, p, ct, cv, cid, csize, coff)
            p += 16
    return bytes(out)


def validate(data, expect_path):
    ver, count, tbl = struct.unpack_from('<III', data, 4)
    if data[:4] != b'CrCh':
        return 'bad signature'
    m = CAF_PATH.search(data)
    if not m or m.group(0).decode() != expect_path:
        return 'clip path not written'
    if struct.unpack_from('<H', data, m.start() - 2)[0] != len(expect_path):
        return 'length field wrong'
    p = tbl
    for _ in range(count):
        _, _, _, csize, coff = struct.unpack_from('<HHIII', data, p)
        p += 16
        if coff + csize > len(data):
            return 'chunk overruns file'
    return None


# ---------------------------------------------------------------- line set

def target_lines():
    """StringNames spoken by the quartermaster, with an estimated duration."""
    dlg = os.path.join(REPO, 'data', 'quests', 'mercenaries', 'kutnohorsko',
                       'mercenaries_background_quest', 'quartermaster_dialog.xml')
    spoken = set(re.findall(r'StringName="([^"]+)"',
                            open(dlg, encoding='utf-8-sig').read()))

    loc = os.path.join(REPO, 'localization', 'English_xml.xml')
    text = {m.group(1): m.group(2) for m in
            re.finditer(r'<Row><Cell>([^<]+)</Cell><Cell>([^<]*)</Cell>',
                        open(loc, encoding='utf-8-sig').read())}

    out = []
    for k in sorted(spoken):
        if k.startswith(PREFIX) and k in text:
            out.append((k, len(text[k]) / CPS, text[k]))
    return out


def main():
    donors = load_index('--rebuild-index' in sys.argv)
    lines = target_lines()
    print('donors: %d (%.2fs - %.2fs)   target lines: %d'
          % (len(donors), donors[0]['dur'], donors[-1]['dur'], len(lines)))

    if os.path.isdir(OUT_DIR):
        for f in glob.glob(os.path.join(OUT_DIR, 'merc_facial_*.dba')):
            os.remove(f)
    else:
        os.makedirs(OUT_DIR)

    opened, used, written, skipped = {}, set(), 0, []
    for name, want, text in lines:
        # closest duration wins; the quartermaster's own voice actor only gets
        # preference when he is a near-equal fit, never at the cost of length
        pool = [d for d in donors if d['leaf'] not in used]
        if not pool:
            skipped.append((name, 'no donor left'))
            continue
        best = min(pool, key=lambda d: abs(d['dur'] - want))
        same = [d for d in pool if d['voice'] == VOICE]
        if same:
            alt = min(same, key=lambda d: abs(d['dur'] - want))
            if abs(alt['dur'] - want) <= abs(best['dur'] - want) + SAME_VOICE_SLACK:
                best = alt
        used.add(best['leaf'])

        pak = os.path.join(GAME, 'Data', 'Facials', best['pak'])
        if pak not in opened:
            opened[pak] = zipfile.ZipFile(pak)

        caf = '%s/%s_%s.caf' % (CAF_ROOT, VOICE, name.lower())
        data = retarget(opened[pak].read(best['dba']), caf)
        err = validate(data, caf)
        if err:
            skipped.append((name, err))
            continue

        open(os.path.join(OUT_DIR, 'merc_facial_%s.dba' % name), 'wb').write(data)
        written += 1
        print('  %-30s %4.1fs  <- %-42s %4.1fs' % (name, want, best['leaf'], best['dur']))

    print()
    print('wrote %d dba(s) to %s' % (written, os.path.relpath(OUT_DIR, REPO)))
    for name, why in skipped:
        print('  SKIPPED %s: %s' % (name, why))


if __name__ == '__main__':
    main()
