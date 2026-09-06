"""Turn a male mercenary voice line into a female-sounding one.

THE PROBLEM. The female mercs are male-bodied soldiers with female heads (see
docs/female-mercenaries.md), and every line the company owns was recorded by a man. They are
currently muted rather than talking in a man's voice. To give them combat cries we need female
audio for lines that only exist as male recordings.

THE APPROACH, and why it is not a neural voice-conversion model.

Combat vocalisation is mostly NON-VERBAL: shouts, grunts, efforts, cries. Speech-trained
converters (RVC, so-vits-svc, FreeVC) are trained to reconstruct *speech* from a content
encoder, and on a scream or a grunt they tend either to smear it into something speech-shaped
or to pass it through barely changed. They also want a target-speaker model, hundreds of MB of
weights and, realistically, a GPU - on a notebook with a UHD 620 that is a slow and uncertain
road for material they are not well suited to.

Signal processing is the better fit here precisely BECAUSE it does not understand the content:
it preserves the performance - the timing, the rasp, the effort, the breath - and changes only
the two things that actually carry perceived sex in a voice:

  1. PITCH (f0). An adult male speaking voice sits around 110 Hz, a female around 200 Hz. That
     is roughly +7 semitones, but a shout is not a spoken vowel and pushing that far on a grunt
     makes it squeak, so the default here is gentler.
  2. FORMANTS - the resonances of the vocal tract. A female tract is about 12-18% shorter, so
     the formants sit that much higher. THIS IS THE HALF THAT MATTERS. Shifting pitch alone
     gives a man speaking falsetto; shifting formants alone gives a smaller man. Both together
     is what reads as a woman.

The two must be controlled SEPARATELY, which is the whole trick:

  * resampling (asetrate + atempo back to length) scales pitch and formants TOGETHER by r;
  * rubberband with formant=preserved scales pitch alone by p.

So chaining them gives formants x r and pitch x (r * p) - any combination we like. This ffmpeg
is built --enable-librubberband (checked), so no installs are needed at all.

MEASURED, NOT ASSUMED. Nobody working on this can hear the output, so verify() measures the
median f0 by autocorrelation and the spectral centroid before and after, and the tool prints
both. A preset that claims +5 semitones and moves f0 by +1 is a preset that did not work.

Usage:
    python tools/voice_feminise.py --sample                 # build the comparison set
    python tools/voice_feminise.py in.ogg out.ogg --preset natural
    python tools/voice_feminise.py --list
"""
import argparse
import math
import os
import struct
import subprocess
import sys
import wave

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))



# THREE VOICES, not one preset applied three times.
#
# The mod fakes three male voices (jcom / phos2 / sbar) largely by FILENAME: of the 147
# distinct recordings in voice/barks, 77 are copied under all three abbreviations and only 53
# are unique to one. So converting once and copying would give three identical women. Each
# abbreviation gets its own formant/pitch pair instead, which costs nothing and actually
# produces three distinguishable voices.
#
# formant = vocal-tract scaling (a woman's tract is ~12-18% shorter, so formants sit that much
# higher - THIS is the half that reads as female). pitch = EXTRA semitones on top of what the
# resample already did. Total shift = 12*log2(formant) + pitch.
VOICES = {
    'jcom':  dict(formant=1.18, pitch=3.5),   # younger, brighter
    'phos2': dict(formant=1.14, pitch=2.5),   # middle
    'sbar':  dict(formant=1.11, pitch=1.0),   # older, lower - the veteran
}

PRESETS = {
    # the three shipping voices, by name
    'voiceA':   VOICES['jcom'],
    'voiceB':   VOICES['phos2'],
    'voiceC':   VOICES['sbar'],
    # Diagnostics, kept so the comparison shows WHY both halves are needed.
    # Formants only, no extra pitch: a smaller, lighter voice.
    'formant':  dict(formant=1.20, pitch=0.0),
    # Pitch only, formants barely moved: the "man in falsetto" failure mode.
    'pitchonly': dict(formant=1.02, pitch=6.0),
    # Deliberately overcooked, to show where it breaks.
    'toofar':   dict(formant=1.28, pitch=6.0),
}


def run(cmd):
    p = subprocess.run(cmd, capture_output=True)
    if p.returncode != 0:
        raise RuntimeError(cmd[0] + ' failed: ' + p.stderr.decode('utf-8', 'replace')[-800:])
    return p.stdout


def probe_rate(path):
    out = run(['ffprobe', '-v', 'error', '-select_streams', 'a:0',
               '-show_entries', 'stream=sample_rate', '-of', 'csv=p=0', path])
    return int(out.decode().strip().split(',')[0])


def filter_chain(rate, formant, pitch_semitones):
    """formant scales the whole spectrum (pitch AND formants); rubberband then moves pitch
    alone. atempo undoes the speed change the resample introduced - it is capped at 2.0 per
    instance, but our ratios are ~1.1-1.2 so one stage is always enough."""
    parts = []
    if abs(formant - 1.0) > 1e-6:
        parts.append('asetrate=%d' % int(round(rate * formant)))
        parts.append('aresample=%d' % rate)
        parts.append('atempo=%.6f' % (1.0 / formant))
    if abs(pitch_semitones) > 1e-6:
        parts.append('rubberband=pitch=%.6f:formant=preserved:pitchq=quality'
                     % (2.0 ** (pitch_semitones / 12.0)))
    return ','.join(parts) if parts else 'anull'


def convert(src, dst, formant, pitch, rate=None):
    rate = rate or probe_rate(src)
    os.makedirs(os.path.dirname(os.path.abspath(dst)), exist_ok=True)
    run(['ffmpeg', '-y', '-v', 'error', '-i', src,
         '-af', filter_chain(rate, formant, pitch),
         '-ar', str(rate), '-ac', '1',
         # The vanilla lines are Vorbis; -q:a 5 is transparent for speech at 48k and keeps the
         # files close to the originals in size.
         '-c:a', 'libvorbis', '-q:a', '5', dst])
    return dst


# ---------------------------------------------------------------- measurement

def load_mono(path):
    """Decode to float32 mono via ffmpeg, without needing soundfile/librosa."""
    wav = run(['ffmpeg', '-v', 'error', '-i', path, '-f', 'wav', '-ac', '1',
               '-c:a', 'pcm_s16le', '-'])
    # find the data chunk rather than assuming a 44-byte header
    i = wav.find(b'data')
    if i < 0:
        raise RuntimeError('no data chunk in decoded wav')
    n = struct.unpack('<I', wav[i + 4:i + 8])[0]
    pcm = np.frombuffer(wav[i + 8:i + 8 + n], dtype='<i2').astype(np.float32) / 32768.0
    rate = struct.unpack('<I', wav[wav.find(b'fmt ') + 12:wav.find(b'fmt ') + 16])[0]
    return pcm, rate


def median_f0(x, rate, fmin=60.0, fmax=400.0):
    """Median f0 over voiced frames, by normalised autocorrelation with octave correction.

    The naive version of this - take the largest peak in the lag window - reported a male
    shout at 289 Hz and then claimed the feminised copy was LOWER than the original, which is
    the classic octave error: autocorrelation peaks at the true period AND at every fraction of
    it, and on a rough, noisy voice the half-period peak can win. Since nobody on this end can
    hear the files, the measurement is the only evidence there is, so it has to be right.

    The fix is the standard one: after finding the best lag, walk the integer multiples of it
    and take the LONGEST lag that still scores nearly as well - i.e. prefer the lower octave
    when the evidence is close.
    """
    win = int(0.045 * rate)
    hop = int(0.015 * rate)
    lo, hi = max(2, int(rate / fmax)), int(rate / fmin)
    out = []
    for s in range(0, max(0, len(x) - win), hop):
        f = x[s:s + win]
        if np.sqrt(np.mean(f * f)) < 0.02:      # silence / breath
            continue
        f = f - f.mean()
        ac = np.correlate(f, f, 'full')[len(f) - 1:]
        if ac[0] <= 0 or len(ac) <= hi:
            continue
        # normalise so peaks at long lags are not penalised by the shrinking overlap
        norm = ac / (ac[0] + 1e-12)
        seg = norm[lo:hi]
        if len(seg) == 0:
            continue
        k = int(np.argmax(seg)) + lo
        best = norm[k]
        if best < 0.3:                          # unvoiced
            continue
        # octave correction: prefer the longest multiple of k that still scores >= 85% of best
        for m in (4, 3, 2):
            km = k * m
            if km < hi and norm[km] >= 0.85 * best:
                k = km
                break
        out.append(rate / k)
    return float(np.median(out)) if out else float('nan')


def spectral_centroid(x, rate):
    if len(x) < 2048:
        return float('nan')
    w = np.hanning(2048)
    cs = []
    for s in range(0, len(x) - 2048, 1024):
        f = x[s:s + 2048]
        if np.sqrt(np.mean(f * f)) < 0.02:
            continue
        mag = np.abs(np.fft.rfft(f * w))
        if mag.sum() <= 0:
            continue
        freqs = np.fft.rfftfreq(2048, 1.0 / rate)
        cs.append(float((mag * freqs).sum() / mag.sum()))
    return float(np.median(cs)) if cs else float('nan')


def hf_fraction(x, rate, cutoff=6000.0):
    """Share of spectral energy above `cutoff`. A voice sits mostly below it; a decoder fed the
    wrong codebooks produces broadband hash that does not. This is the cheap, reliable tell for
    "this file is noise" when nobody on this end can listen to it."""
    n = 4096
    if len(x) < n:
        return 0.0
    w = np.hanning(n)
    acc = np.zeros(n // 2 + 1)
    cnt = 0
    for s in range(0, len(x) - n, n // 2):
        acc += np.abs(np.fft.rfft(x[s:s + n] * w))
        cnt += 1
    if not cnt:
        return 0.0
    fr = np.fft.rfftfreq(n, 1.0 / rate)
    tot = acc.sum() + 1e-9
    return float(acc[fr >= cutoff].sum() / tot)


def worst_window_hf(x, rate, win=0.25, cutoff=6000.0, floor=0.15):
    """The brightest quarter-second in the file, judging only windows loud enough to hear.

    `floor` is a fraction of the file's peak, not an absolute RMS. That matters: an HF *ratio*
    is meaningless at very low level, because what is left in a decaying breath tail is mostly
    broadband noise and the ratio goes high while the sound is inaudible. Measured on a real
    audition track, the two windows this check originally condemned sat at 4.1% and 2.5% of
    peak - 28 and 32 dB down - while every window carrying actual voice was under 16%. Judging
    those tails made the metric report noise in audio that was provably clean at every stage.
    """
    n = int(win * rate)
    peak = float(np.max(np.abs(x))) if len(x) else 0.0
    if peak <= 0:
        return 0.0
    worst = 0.0
    for s in range(0, max(1, len(x) - n), n):
        w = x[s:s + n]
        if float(np.sqrt(np.mean(w * w))) < floor * peak:
            continue
        worst = max(worst, hf_fraction(w, rate, cutoff))
    return worst


def describe(path):
    x, rate = load_mono(path)
    return median_f0(x, rate), spectral_centroid(x, rate), len(x) / float(rate)


def verify(src, dst, want_semitones):
    """Prove the transform did what the preset claims. Returns a printable line."""
    f0a, sca, da = describe(src)
    f0b, scb, db = describe(dst)
    got = 12 * math.log2(f0b / f0a) if (f0a == f0a and f0b == f0b and f0a > 0) else float('nan')
    return ('f0 %6.1f -> %6.1f Hz (%+.1f st, asked %+.1f)   '
            'centroid %5.0f -> %5.0f Hz   length %.2fs -> %.2fs'
            % (f0a, f0b, got, want_semitones, sca, scb, da, db))


# ---------------------------------------------------------------- sample set

# Deliberately varied: two ordinary spoken lines, a sigh and a grunted curse - the last two
# being the closest thing in the mod's existing set to the combat efforts this is really for.
SAMPLE_SOURCES = [
    'voice/barks/jcom_obec_povzdech__ugh_kurva_4hCW.ogg',   # grunt / curse
    'voice/barks/jcom_obec_povzdech__eh_boze_PEVa.ogg',     # sigh
    'voice/barks/jcom_band_event_cri_uz_bych_ne_8fgC.ogg',  # longer speech
    'voice/barks/jcom_bark_vasko_jdeme_WqB2.ogg',           # short order
]


def build_sample(outdir):
    os.makedirs(outdir, exist_ok=True)
    order = ['voiceA', 'voiceB', 'voiceC', 'formant', 'pitchonly', 'toofar']
    made = []
    for src in SAMPLE_SOURCES:
        s = os.path.join(ROOT, src)
        if not os.path.isfile(s):
            print('  missing source: %s' % src)
            continue
        stem = os.path.splitext(os.path.basename(src))[0]
        orig = os.path.join(outdir, '%s__0_ORIGINAL_male.ogg' % stem)
        run(['ffmpeg', '-y', '-v', 'error', '-i', s, '-c:a', 'libvorbis', '-q:a', '5', orig])
        made.append(orig)
        f0a, sca, _ = describe(s)
        print('\n%s   (source f0 %.0f Hz, centroid %.0f Hz)' % (stem, f0a, sca))
        for name in order:
            p = PRESETS[name]
            dst = os.path.join(outdir, '%s__%s.ogg' % (stem, name))
            convert(s, dst, p['formant'], p['pitch'])
            total = 12 * math.log2(p['formant']) + p['pitch']
            print('  %-10s formant x%.2f pitch %+.1f (total %+.1f st)  %s'
                  % (name, p['formant'], p['pitch'], total, verify(s, dst, total)))
            made.append(dst)
    return made


def say(text, dst, rate=48000):
    """A spoken separator, so an audition track announces what you are about to hear.

    ffmpeg's flite filter is compiled in (--enable-libflite). Its voice is robotic, which is
    fine and arguably useful: nobody will mistake the label for the sample.
    """
    try:
        run(['ffmpeg', '-y', '-v', 'error', '-f', 'lavfi',
             '-i', 'flite=voice=slt:text=%s' % text.replace(':', ' ').replace("'", ''),
             '-af', 'aresample=%d,volume=0.5' % rate, '-ac', '1',
             '-c:a', 'libvorbis', '-q:a', '3', dst])
        return dst
    except Exception:
        return None


def audition(outdir, sources, treatments, tag):
    """One file per source: the original then each treatment, announced and gapped, so the
    comparison can actually be listened to instead of shuffling 28 loose files."""
    os.makedirs(outdir, exist_ok=True)
    made = []
    for src in sources:
        s = os.path.join(ROOT, src)
        if not os.path.isfile(s):
            print('  missing source: %s' % src)
            continue
        stem = os.path.splitext(os.path.basename(src))[0]
        work = os.path.join(outdir, '_work')
        os.makedirs(work, exist_ok=True)
        # A one-second gap between takes, and NO spoken labels. flite's synthetic voice is
        # bright and buzzy, and after shipping one genuinely painful file the right move is to
        # take the extra synthesiser out of the signal path rather than reason about whether
        # its brightness is acceptable. The order is in the caption instead.
        gap = os.path.join(work, '_gap.ogg')
        if not os.path.isfile(gap):
            run(['ffmpeg', '-y', '-v', 'error', '-f', 'lavfi',
                 '-i', 'anullsrc=r=48000:cl=mono', '-t', '1.0',
                 '-c:a', 'libvorbis', '-q:a', '3', gap])
        parts = []
        for i, name in enumerate(['ORIGINAL'] + treatments):
            if i:
                parts.append(gap)
            clip = os.path.join(work, '%s_%d_clip.ogg' % (stem, i))
            if name == 'ORIGINAL':
                run(['ffmpeg', '-y', '-v', 'error', '-i', s,
                     '-ac', '1', '-c:a', 'libvorbis', '-q:a', '5', clip])
            else:
                p = PRESETS[name]
                convert(s, clip, p['formant'], p['pitch'])
            parts.append(clip)
        lst = os.path.join(work, '%s.txt' % stem)
        # NEVER the concat DEMUXER here. It joins packets without re-initialising the decoder,
        # and Vorbis carries its codebooks in per-file extradata - so everything after the
        # first input decodes against the wrong codebooks and comes out as noise. The first
        # audition built that way measured 1.7% of samples clipping and 44% of its energy
        # above 6 kHz against the source's 11%: an ear-splitting screech, from files whose
        # individual conversions were perfect. Use the concat FILTER, which decodes each input
        # properly, and normalise so the joined track cannot clip.
        dst = os.path.join(outdir, '%s__%s.ogg' % (tag, stem))
        cmd = ['ffmpeg', '-y', '-v', 'error']
        for p in parts:
            cmd += ['-i', p]
        chain = ''.join('[%d:a]aresample=48000,aformat=sample_fmts=fltp:channel_layouts=mono[a%d];'
                        % (i, i) for i in range(len(parts)))
        chain += ''.join('[a%d]' % i for i in range(len(parts)))
        chain += 'concat=n=%d:v=0:a=1[out]' % len(parts)
        cmd += ['-filter_complex', chain, '-map', '[out]',
                '-ac', '1', '-ar', '48000', '-c:a', 'libvorbis', '-q:a', '5', dst]
        run(cmd)

        # Prove it before it goes anywhere. The individual conversions were verified and the
        # broken thing was the container step, so the check has to be on the FILE THAT SHIPS.
        x, r = load_mono(dst)
        xs, _ = load_mono(s)
        peak = float(np.max(np.abs(x)))
        clipped = float(np.mean(np.abs(x) > 0.99))
        if peak > 0.995 or clipped > 0.0005:
            raise RuntimeError('%s: peak %.3f, %.2f%% clipped - refusing to emit'
                               % (os.path.basename(dst), peak, clipped * 100))
        # Window-by-window, not just the average: one screeching half-second hides completely
        # in a mean taken over twelve seconds.
        #
        # The comparison has to allow for what the transform legitimately does. Scaling the
        # formants by r moves energy at frequency f up to f*r, so energy above 6 kHz in the
        # OUTPUT corresponds to energy above 6000/r in the SOURCE - measuring both at 6 kHz
        # would condemn the effect we are deliberately applying. This material is Czech and
        # full of sibilants; the untouched male recording already reaches 35% above 6 kHz on a
        # /s/, so an absolute limit is useless in the other direction too.
        rmax = max(PRESETS[t]['formant'] for t in treatments)
        hf_out = worst_window_hf(x, r)
        hf_src = worst_window_hf(xs, r, cutoff=6000.0 / rmax)
        if hf_out > max(hf_src * 1.4, hf_src + 0.10):
            raise RuntimeError('%s: worst window %.0f%% above 6 kHz against the source\'s '
                               '%.0f%% above %.0f Hz - that is noise, not sibilance'
                               % (os.path.basename(dst), hf_out * 100, hf_src * 100,
                                  6000.0 / rmax))
        made.append(dst)
        print('  %-52s peak %.2f  worst window >6kHz %.0f%% (source %.0f%%)'
              % (os.path.basename(dst), peak, hf_out * 100, hf_src * 100))
    return made


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--audition', action='store_true',
                    help='build listenable A/B tracks instead of loose files')
    ap.add_argument('src', nargs='?')
    ap.add_argument('dst', nargs='?')
    ap.add_argument('--preset', default='voiceB', choices=sorted(PRESETS))
    ap.add_argument('--formant', type=float)
    ap.add_argument('--pitch', type=float)
    ap.add_argument('--sample', action='store_true')
    ap.add_argument('--outdir', default=os.path.join(ROOT, 'tmp', 'voice_sample'))
    ap.add_argument('--list', action='store_true')
    a = ap.parse_args()

    if a.list:
        for k, v in sorted(PRESETS.items()):
            print('%-10s formant x%.2f  extra pitch %+.1f st  (total %+.1f st)'
                  % (k, v['formant'], v['pitch'], 12 * math.log2(v['formant']) + v['pitch']))
        return 0

    if a.audition:
        print('the three voices:')
        made = audition(a.outdir, SAMPLE_SOURCES[:3], ['voiceA', 'voiceB', 'voiceC'], 'VOICES')
        print('why both halves are needed:')
        made += audition(a.outdir, SAMPLE_SOURCES[:1],
                         ['formant', 'pitchonly', 'voiceB', 'toofar'], 'WHY')
        print('\n%d audition tracks in %s' % (len(made), a.outdir))
        return 0

    if a.sample:
        made = build_sample(a.outdir)
        print('\n%d files in %s' % (len(made), a.outdir))
        return 0

    if not a.src or not a.dst:
        ap.error('need src and dst (or --sample)')
    p = PRESETS[a.preset]
    formant = a.formant if a.formant is not None else p['formant']
    pitch = a.pitch if a.pitch is not None else p['pitch']
    convert(a.src, a.dst, formant, pitch)
    print(verify(a.src, a.dst, 12 * math.log2(formant) + pitch))
    return 0


if __name__ == '__main__':
    sys.exit(main())
