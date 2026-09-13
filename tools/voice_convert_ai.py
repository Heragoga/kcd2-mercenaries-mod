"""Neural voice conversion: turn a male mercenary line into one of the game's own actresses.

WHY NOT THE DSP TOOL. tools/voice_feminise.py shifts pitch and formants, which is the textbook
male->female recipe and is genuinely all you can do without a model. Judged in game it came
back as "more like a cartoon villain" - correct, and the reason is that pitch and vocal-tract
length are not what identifies a speaker. TIMBRE is: the fine structure of the spectral
envelope, the glottal source, the way formants move between phonemes. No amount of shifting
invents that, it only relocates what the man's voice already had. A converter has to resynthesise
the voice, not transform it.

THE TARGET IS VANILLA. The whole reason this is worth doing properly: KCD2 ships hours of
professionally recorded female VO by the actresses the game already uses, and the mod's female
souls are assigned ten of them:

    rris  Rebecca Risness     jpres Jennifer Preston   aric  Mia Allis
    tsho  Tegen Short         sphe  Sinead Phelps      bros  Bethan Rose Young
    mryc  Martina Klier       bmcf  Sandra Osgerby     jber  Jade Becker
    lcar  Lily Carr

Converting toward one of those means the result carries the right accent, the right recording
chain and the right performance register, and sits beside vanilla female NPCs without standing
out. A generic model voice would not.

WHY kNN-VC. Most one-shot converters take a few seconds of reference and encode it to a single
speaker embedding. Here we have THOUSANDS of lines per actress, and kNN-VC is the method that
can actually use them: it encodes source and target to WavLM features and replaces each source
frame with the mean of its nearest neighbours in the target's feature pool, then vocodes. More
target audio directly improves it. It also keeps the source's timing and delivery, which is
what matters for combat efforts - a grunt stays a grunt.

    python tools/voice_convert_ai.py pool --voice rris          # build a target pool
    python tools/voice_convert_ai.py convert in.ogg out.ogg --voice rris
    python tools/voice_convert_ai.py sample --voice rris
"""
import argparse
import os
import random
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
VOICEDIR = os.path.join(ROOT, 'references', 'voice')
POOLROOT = os.path.join(ROOT, 'tmp', 'vc_pool')

# voice_id -> abbreviation, from Libs/Tables/skald/voice.xml. These ten are the ones the mod's
# female skald_character rows already point at (skald_character__mercenaries.xml).
FEMALE_VOICES = {
    'rris': 'Rebecca Risness', 'jpres': 'Jennifer Preston', 'aric': 'Mia Allis',
    'tsho': 'Tegen Short', 'sphe': 'Sinead Phelps', 'bros': 'Bethan Rose Young',
    'mryc': 'Martina Klier', 'bmcf': 'Sandra Osgerby', 'jber': 'Jade Becker',
    'lcar': 'Lily Carr',
}
MALE_VOICES = {'sbar': 'Sam Barlien', 'phos2': 'Peter Hosking', 'jcom': 'John Comer'}

SR = 16000          # WavLM operates at 16 kHz
POOL_SECONDS = 420  # ~7 minutes of target audio; kNN needs a pool, not a clip


def run(cmd, **kw):
    p = subprocess.run(cmd, capture_output=True, **kw)
    if p.returncode != 0:
        raise RuntimeError('%s failed:\n%s' % (cmd[0], p.stderr.decode('utf-8', 'replace')[-1200:]))
    return p.stdout


def duration(path):
    try:
        out = run(['ffprobe', '-v', 'error', '-show_entries', 'format=duration',
                   '-of', 'csv=p=0', path])
        return float(out.decode().strip())
    except Exception:
        return 0.0


def find_lines(abbrev, limit=None):
    """Every extracted .ogg belonging to one voice. Files are <abbrev>_<slug>_<hash>.ogg."""
    hits = []
    prefix = abbrev + '_'
    for dirpath, _dirs, files in os.walk(VOICEDIR):
        for f in files:
            if f.startswith(prefix) and f.endswith('.ogg'):
                hits.append(os.path.join(dirpath, f))
                if limit and len(hits) >= limit:
                    return hits
    return hits


def build_pool(abbrev, seconds=POOL_SECONDS, seed=7):
    """Decode a spread of one actress's lines to 16 kHz mono wavs.

    Sampled at random across the whole extracted set rather than taken in directory order: the
    tree is grouped by quest, so the first N files would all be one scene in one emotional
    register. A pool that only contains her being frightened converts everything to frightened.
    """
    if abbrev not in FEMALE_VOICES:
        raise SystemExit('unknown voice %r - one of: %s' % (abbrev, ', '.join(sorted(FEMALE_VOICES))))
    out = os.path.join(POOLROOT, abbrev)
    os.makedirs(out, exist_ok=True)
    have = sum(duration(os.path.join(out, f)) for f in os.listdir(out) if f.endswith('.wav'))
    if have >= seconds * 0.9:
        print('pool for %s already has %.0fs' % (abbrev, have))
        return out

    files = find_lines(abbrev)
    if not files:
        raise SystemExit('no extracted lines for %s under %s' % (abbrev, VOICEDIR))
    random.Random(seed).shuffle(files)
    print('%s (%s): %d lines available, taking ~%ds' % (abbrev, FEMALE_VOICES[abbrev],
                                                        len(files), seconds))
    # Decode first and read the length off the file size, rather than calling ffprobe on every
    # candidate and then ffmpeg on the survivors. At 16 kHz mono 16-bit that is bytes/32000,
    # exactly - and it halves the number of processes, which on this machine is the whole cost.
    total, n = have, 0
    for src in files:
        if total >= seconds:
            break
        dst = os.path.join(out, '%04d.wav' % n)
        try:
            run(['ffmpeg', '-y', '-v', 'error', '-i', src, '-ac', '1', '-ar', str(SR),
                 '-c:a', 'pcm_s16le', dst])
        except Exception:
            continue
        d = (os.path.getsize(dst) - 44) / float(SR * 2)
        # Skip the very short and the very long: a 0.3 s grunt adds nothing to a feature pool,
        # and a 30 s monologue is usually a cutscene with music or effects under it.
        if d < 1.0 or d > 12.0:
            os.remove(dst)
            continue
        total += d
        n += 1
    print('  %d files, %.0f s in %s' % (n, total, os.path.relpath(out, ROOT)))
    return out


# ---------------------------------------------------------------- kNN-VC

_MODEL = [None]


def get_model():
    """Load kNN-VC once. Pulls WavLM-Large and the prematched HiFiGAN through torch.hub on
    first use (~1.5 GB, cached under ~/.cache/torch)."""
    if _MODEL[0] is None:
        import torch
        torch.set_num_threads(max(1, (os.cpu_count() or 4)))
        print('loading kNN-VC (first run downloads WavLM + HiFiGAN, ~1.5 GB)...')
        _MODEL[0] = torch.hub.load('bshall/knn-vc', 'knn_vc', prematched=True,
                                   trust_repo=True, pretrained=True, device='cpu')
    return _MODEL[0]


def matching_set(abbrev, cache=True):
    """WavLM features for a whole target pool.

    Cached: encoding seven minutes of audio is the slow part on a CPU, and it is identical for
    every line converted toward that actress. Without the cache a hundred-line batch would pay
    for it a hundred times.
    """
    import torch
    pool = os.path.join(POOLROOT, abbrev)
    if not os.path.isdir(pool):
        build_pool(abbrev)
    wavs = sorted(os.path.join(pool, f) for f in os.listdir(pool) if f.endswith('.wav'))
    if not wavs:
        raise SystemExit('empty pool for %s' % abbrev)
    cpath = os.path.join(POOLROOT, '%s_matching.pt' % abbrev)
    if cache and os.path.isfile(cpath):
        return torch.load(cpath, map_location='cpu')
    m = get_model()
    print('  encoding %d target files for %s...' % (len(wavs), abbrev))
    ms = m.get_matching_set(wavs)
    if cache:
        torch.save(ms, cpath)
    return ms


def convert_file(src, dst, abbrev, topk=4):
    """One line, male -> the chosen actress. Output is written at the source's sample rate."""
    import torch, torchaudio
    m = get_model()
    ms = matching_set(abbrev)
    q = m.get_features(src)
    wav = m.match(q, ms, topk=topk)          # 1-D tensor at 16 kHz
    tmp = dst + '.16k.wav'
    torchaudio.save(tmp, wav[None].cpu(), SR)
    # Back to the game's 48 kHz Vorbis, and normalise to the source's peak so a converted line
    # sits at the same level as the rest of the company's audio.
    run(['ffmpeg', '-y', '-v', 'error', '-i', tmp, '-ar', '48000', '-ac', '1',
         '-af', 'loudnorm=I=-19:TP=-1.5:LRA=11', '-c:a', 'libvorbis', '-q:a', '5', dst])
    os.remove(tmp)
    return dst


def cmd_convert(a):
    convert_file(a.src, a.dst, a.voice, a.topk)
    print('wrote', a.dst)
    return 0


def cmd_pool(a):
    for v in (a.voice or sorted(FEMALE_VOICES)):
        build_pool(v, a.seconds)
    return 0


SAMPLE_SOURCES = [
    'voice/barks/jcom_obec_povzdech__ugh_kurva_4hCW.ogg',   # grunt / curse - closest to combat
    'voice/barks/jcom_band_event_cri_uz_bych_ne_8fgC.ogg',  # speech
    'voice/barks/jcom_obec_povzdech__eh_boze_PEVa.ogg',     # sigh
]


def cmd_sample(a):
    """Audition track per source: the male original, then the same line as each actress.

    Joined with the concat FILTER and gaps, never the concat demuxer - that decodes Vorbis
    against the wrong per-file codebooks and produces noise, which is how an earlier version of
    this work shipped an ear-splitting file. Every result is measured before it is emitted.
    """
    sys.path.insert(0, os.path.join(ROOT, 'tools'))
    from voice_feminise import load_mono, worst_window_hf
    import numpy as np

    voices = a.voice or ['rris', 'aric', 'bros']
    outdir = a.outdir
    work = os.path.join(outdir, '_work')
    os.makedirs(work, exist_ok=True)
    gap = os.path.join(work, '_gap.ogg')
    run(['ffmpeg', '-y', '-v', 'error', '-f', 'lavfi', '-i', 'anullsrc=r=48000:cl=mono',
         '-t', '1.0', '-c:a', 'libvorbis', '-q:a', '3', gap])

    made = []
    for rel in SAMPLE_SOURCES:
        src = os.path.join(ROOT, rel)
        if not os.path.isfile(src):
            print('missing', rel)
            continue
        stem = os.path.splitext(os.path.basename(rel))[0]
        parts = []
        o = os.path.join(work, '%s_orig.ogg' % stem)
        run(['ffmpeg', '-y', '-v', 'error', '-i', src, '-ac', '1', '-ar', '48000',
             '-c:a', 'libvorbis', '-q:a', '5', o])
        parts.append(o)
        for v in voices:
            c = os.path.join(work, '%s_%s.ogg' % (stem, v))
            print('  %s -> %s (%s)' % (stem, v, FEMALE_VOICES[v]))
            convert_file(src, c, v)
            parts += [gap, c]

        dst = os.path.join(outdir, 'AI__%s.ogg' % stem)
        cmd = ['ffmpeg', '-y', '-v', 'error']
        for p in parts:
            cmd += ['-i', p]
        ch = ''.join('[%d:a]aresample=48000,aformat=sample_fmts=fltp:channel_layouts=mono[a%d];'
                     % (i, i) for i in range(len(parts)))
        ch += ''.join('[a%d]' % i for i in range(len(parts)))
        ch += 'concat=n=%d:v=0:a=1[out]' % len(parts)
        cmd += ['-filter_complex', ch, '-map', '[out]', '-ac', '1', '-ar', '48000',
                '-c:a', 'libvorbis', '-q:a', '5', dst]
        run(cmd)

        x, r = load_mono(dst)
        peak = float(np.max(np.abs(x)))
        clip = float(np.mean(np.abs(x) > 0.99))
        hf = worst_window_hf(x, r)
        if peak > 0.995 or clip > 0.0005 or hf > 0.45:
            raise RuntimeError('%s: peak %.2f clip %.2f%% worstHF %.0f%% - refusing to emit'
                               % (os.path.basename(dst), peak, clip * 100, hf * 100))
        print('  %-40s peak %.2f  clip %.2f%%  worstHF %.0f%%'
              % (os.path.basename(dst), peak, clip * 100, hf * 100))
        made.append(dst)
    print('\n%d audition tracks in %s' % (len(made), outdir))
    return 0


def main():
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest='cmd', required=True)

    p = sub.add_parser('pool', help='build a target-voice pool from the extracted vanilla VO')
    p.add_argument('--voice', action='append', choices=sorted(FEMALE_VOICES))
    p.add_argument('--seconds', type=int, default=POOL_SECONDS)
    p.set_defaults(func=cmd_pool)

    p = sub.add_parser('convert', help='convert one line')
    p.add_argument('src')
    p.add_argument('dst')
    p.add_argument('--voice', required=True, choices=sorted(FEMALE_VOICES))
    p.add_argument('--topk', type=int, default=4)
    p.set_defaults(func=cmd_convert)

    p = sub.add_parser('sample', help='build an audition: original then each target voice')
    p.add_argument('--voice', action='append', choices=sorted(FEMALE_VOICES))
    p.add_argument('--outdir', default=os.path.join(ROOT, 'tmp', 'vc_sample'))
    p.set_defaults(func=cmd_sample)

    p = sub.add_parser('voices', help='list the voices and how many lines are extracted')
    p.set_defaults(func=lambda a: (
        [print('%-6s %-22s %5d lines' % (k, v, len(find_lines(k))))
         for k, v in sorted(list(FEMALE_VOICES.items()) + list(MALE_VOICES.items()))], 0)[1])

    a = ap.parse_args()
    return a.func(a)


if __name__ == '__main__':
    sys.exit(main())
