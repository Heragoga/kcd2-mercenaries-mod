#!/usr/bin/env python3
"""Clean up and master recorded voice lines so they sit next to KCD2 vanilla dialogue.

Chain: denoise -> dereverb -> de-ess -> EQ -> match-EQ -> gate -> compress
       -> trim -> loudness -> limiter -> encode.

Every parameter is adjustable three ways: a JSON preset (--preset), --set
stage.key=value on the command line, and the slider GUI (voice_master_gui.py).
Pass --ref <vanilla .ogg / folder / glob> to match loudness and tone to real
game dialogue.  See docs/general/voice-mastering.md.
"""

from __future__ import annotations

import argparse
import copy
import glob as globmod
import json
import math
import os
import shutil
import subprocess
import sys

import numpy as np
from scipy import signal, ndimage

SR = 48000
HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_PROFILE = os.path.join(HERE, "vanilla_profile.json")

# ---------------------------------------------------------------- parameters

DEFAULTS = {
    "io": {
        "sample_rate": 48000,
        "format": "ogg",
        "ogg_quality": 6.0,
        "name_template": "{stem}",
        "prefixes": "",
        "decoder": "auto",
        "write_wav_copy": False,
    },
    "prep": {
        "enabled": True,
        "dc_offset": True,
        "highpass_hz": 85.0,
        "highpass_order": 4,
        "lowpass_hz": 0.0,
        "hum_hz": 0.0,
        "hum_harmonics": 4,
        "hum_q": 30.0,
    },
    "denoise": {
        "enabled": True,
        "strength": 0.9,
        "reduction_db": 20.0,
        "oversubtract": 1.5,
        "noise_percentile": 15.0,
        "noise_start": -1.0,
        "noise_end": -1.0,
        "noise_file": "",
        "dd_alpha": 0.94,
        "freq_smooth_hz": 200.0,
        "time_smooth": 0.4,
        "nfft": 2048,
        "overlap": 4,
    },
    "dereverb": {
        "enabled": True,
        "method": "wpe",
        "mix": 1.0,
        "wpe_taps": 12,
        "wpe_delay": 3,
        "wpe_iterations": 3,
        "wpe_nfft": 1024,
        "late_rt60": 0.45,
        "late_delay_ms": 45.0,
        "late_oversubtract": 1.3,
        "late_floor_db": -14.0,
        "late_nfft": 2048,
    },
    "deess": {
        "enabled": True,
        "low_hz": 4500.0,
        "high_hz": 10000.0,
        "auto_threshold": True,
        "auto_percentile": 75.0,
        "threshold_db": -34.0,
        "ratio": 3.5,
        "max_reduction_db": 9.0,
        "attack_ms": 2.0,
        "release_ms": 60.0,
    },
    "eq": {
        "enabled": True,
        "low_shelf_hz": 220.0,
        "low_shelf_db": 0.0,
        "bell1_hz": 300.0,
        "bell1_db": 0.0,
        "bell1_q": 1.0,
        "bell2_hz": 2800.0,
        "bell2_db": 0.0,
        "bell2_q": 0.9,
        "high_shelf_hz": 7000.0,
        "high_shelf_db": 0.0,
        "tilt_db": 0.0,
    },
    "match": {
        "enabled": True,
        "strength": 0.85,
        "max_boost_db": 6.0,
        "max_cut_db": 16.0,
        "smooth_octaves": 0.333,
        "low_hz": 60.0,
        "high_hz": 15000.0,
        "fir_taps": 2047,
        "match_loudness": True,
        "match_noise_floor": False,
        "noise_floor_offset_db": 0.0,
    },
    "gate": {
        "enabled": True,
        "auto_threshold": True,
        "above_floor_db": 12.0,
        "threshold_db": -58.0,
        "range_db": 60.0,
        "attack_ms": 5.0,
        "hold_ms": 120.0,
        "release_ms": 150.0,
    },
    "compress": {
        "enabled": True,
        "threshold_db": -24.0,
        "ratio": 2.6,
        "knee_db": 8.0,
        "attack_ms": 8.0,
        "release_ms": 140.0,
        "makeup_auto": True,
        "makeup_db": 0.0,
    },
    "trim": {
        "enabled": True,
        "above_floor_db": 14.0,
        "head_pad_ms": 80.0,
        "tail_pad_ms": 250.0,
        "fade_ms": 12.0,
    },
    "loudness": {
        "enabled": True,
        "target_lufs": -22.5,
        "peak_ceiling_db": -1.5,
        "limiter": True,
        "limiter_lookahead_ms": 5.0,
        "limiter_release_ms": 120.0,
        "true_peak": True,
    },
}

# dotted key -> (min, max, help).  Drives --list-params and the GUI sliders.
PARAM_META = {
    "io.sample_rate": (8000, 96000, "output sample rate; KCD2 dialogue is 48000"),
    "io.format": (0, 0, "ogg | wav | flac"),
    "io.ogg_quality": (-1, 10, "ffmpeg vorbis -q:a; vanilla sits near 2, mod files use 6"),
    "io.name_template": (0, 0, "output stem, {stem} = input filename without extension"),
    "io.prefixes": (0, 0, "comma list of voice-abbrev copies to emit, e.g. jcom,phos2,sbar"),
    "io.decoder": (0, 0, "auto | soundfile | ffmpeg"),
    "io.write_wav_copy": (0, 1, "also write an uncompressed .wav next to the output"),
    "prep.enabled": (0, 1, "run the prep stage at all"),
    "prep.dc_offset": (0, 1, "subtract mean sample value"),
    "prep.highpass_hz": (0, 300, "rumble / proximity high-pass; 0 disables"),
    "prep.highpass_order": (1, 8, "high-pass steepness (Butterworth order)"),
    "prep.lowpass_hz": (0, 24000, "low-pass; 0 disables"),
    "prep.hum_hz": (0, 120, "mains hum notch fundamental (50 or 60); 0 disables"),
    "prep.hum_harmonics": (1, 10, "how many hum harmonics to notch"),
    "prep.hum_q": (5, 100, "hum notch sharpness"),
    "denoise.enabled": (0, 1, "spectral denoise on/off"),
    "denoise.strength": (0, 1, "blend between untouched and fully denoised"),
    "denoise.reduction_db": (0, 60, "hard cap on how far any bin may be pulled down"),
    "denoise.oversubtract": (0.5, 4, "scales the noise estimate; >1 cleans harder"),
    "denoise.noise_percentile": (1, 50, "per-bin percentile used as the noise profile"),
    "denoise.noise_start": (-1, 600, "seconds; start of a noise-only region (-1 = auto)"),
    "denoise.noise_end": (-1, 600, "seconds; end of that region (-1 = auto)"),
    "denoise.noise_file": (0, 0, "audio file holding room tone only, overrides the auto profile"),
    "denoise.dd_alpha": (0.5, 0.995, "decision-directed smoothing; higher = fewer artefacts, more smear"),
    "denoise.freq_smooth_hz": (0, 1000, "smooth the gain curve across frequency to kill musical noise"),
    "denoise.time_smooth": (0, 0.95, "extra gain smoothing across time"),
    "denoise.nfft": (256, 8192, "STFT size"),
    "denoise.overlap": (2, 8, "STFT overlap factor (hop = nfft / overlap)"),
    "dereverb.enabled": (0, 1, "dereverb on/off"),
    "dereverb.method": (0, 0, "wpe | late | both"),
    "dereverb.mix": (0, 1, "wet/dry blend of the dereverbed signal"),
    "dereverb.wpe_taps": (2, 40, "WPE filter length; longer removes longer tails"),
    "dereverb.wpe_delay": (1, 10, "frames of direct sound WPE must not touch"),
    "dereverb.wpe_iterations": (1, 8, "WPE refinement passes"),
    "dereverb.wpe_nfft": (256, 4096, "WPE STFT size"),
    "dereverb.late_rt60": (0.1, 2.0, "room RT60 in seconds for the 'late' method"),
    "dereverb.late_delay_ms": (10, 150, "start of the late field, ms after direct sound"),
    "dereverb.late_oversubtract": (0.5, 3, "how hard to subtract the late field"),
    "dereverb.late_floor_db": (-40, 0, "floor for the late-field subtraction"),
    "dereverb.late_nfft": (256, 8192, "STFT size for the 'late' method"),
    "deess.enabled": (0, 1, "de-esser on/off"),
    "deess.low_hz": (2000, 9000, "bottom of the sibilant band"),
    "deess.high_hz": (5000, 20000, "top of the sibilant band"),
    "deess.auto_threshold": (0, 1, "derive the threshold from this take instead of a fixed dBFS"),
    "deess.auto_percentile": (50, 99, "percentile of band level used as the auto threshold"),
    "deess.threshold_db": (-70, 0, "fixed threshold when auto_threshold is off"),
    "deess.ratio": (1, 10, "de-esser ratio"),
    "deess.max_reduction_db": (0, 24, "cap on sibilant gain reduction"),
    "deess.attack_ms": (0.2, 20, "de-esser attack"),
    "deess.release_ms": (10, 400, "de-esser release"),
    "eq.enabled": (0, 1, "static EQ on/off"),
    "eq.low_shelf_hz": (40, 600, "low shelf corner"),
    "eq.low_shelf_db": (-18, 12, "low shelf gain"),
    "eq.bell1_hz": (60, 1000, "mud bell frequency"),
    "eq.bell1_db": (-18, 12, "mud bell gain"),
    "eq.bell1_q": (0.2, 8, "mud bell Q"),
    "eq.bell2_hz": (800, 8000, "presence bell frequency"),
    "eq.bell2_db": (-18, 12, "presence bell gain"),
    "eq.bell2_q": (0.2, 8, "presence bell Q"),
    "eq.high_shelf_hz": (2000, 16000, "high shelf corner"),
    "eq.high_shelf_db": (-18, 12, "high shelf gain"),
    "eq.tilt_db": (-12, 12, "broadband tilt, positive = brighter"),
    "match.enabled": (0, 1, "match the reference's tone and loudness"),
    "match.strength": (0, 1, "how much of the measured correction curve to apply"),
    "match.max_boost_db": (0, 24, "cap on boosts in the match curve"),
    "match.max_cut_db": (0, 40, "cap on cuts in the match curve"),
    "match.smooth_octaves": (0.05, 2, "log-frequency smoothing of the match curve"),
    "match.low_hz": (20, 2000, "below this the match curve fades to flat"),
    "match.high_hz": (2000, 24000, "above this the match curve fades to flat"),
    "match.fir_taps": (65, 8191, "length of the match FIR (odd)"),
    "match.match_loudness": (0, 1, "take the loudness target from the reference"),
    "match.match_noise_floor": (0, 1, "add shaped room tone so silences are not unnaturally dead"),
    "match.noise_floor_offset_db": (-24, 12, "trim on the added room tone level"),
    "gate.enabled": (0, 1, "downward expander on/off"),
    "gate.auto_threshold": (0, 1, "set the threshold relative to the measured noise floor"),
    "gate.above_floor_db": (0, 40, "how far above the noise floor the auto threshold sits"),
    "gate.threshold_db": (-90, 0, "fixed threshold when auto_threshold is off"),
    "gate.range_db": (0, 80, "how far the gate closes"),
    "gate.attack_ms": (0.5, 50, "gate attack"),
    "gate.hold_ms": (0, 1000, "gate hold"),
    "gate.release_ms": (20, 2000, "gate release"),
    "compress.enabled": (0, 1, "compressor on/off"),
    "compress.threshold_db": (-60, 0, "compressor threshold"),
    "compress.ratio": (1, 20, "compressor ratio"),
    "compress.knee_db": (0, 24, "soft knee width"),
    "compress.attack_ms": (0.5, 100, "compressor attack"),
    "compress.release_ms": (20, 1000, "compressor release"),
    "compress.makeup_auto": (0, 1, "restore the loudness the compressor took away"),
    "compress.makeup_db": (-12, 24, "extra make-up gain"),
    "trim.enabled": (0, 1, "trim leading and trailing silence"),
    "trim.above_floor_db": (0, 40, "speech detection threshold above the noise floor"),
    "trim.head_pad_ms": (0, 1000, "silence kept before the first word"),
    "trim.tail_pad_ms": (0, 2000, "silence kept after the last word"),
    "trim.fade_ms": (0, 100, "fade in/out applied at the trim points"),
    "loudness.enabled": (0, 1, "loudness normalisation on/off"),
    "loudness.target_lufs": (-40, -6, "integrated loudness target (BS.1770-4)"),
    "loudness.peak_ceiling_db": (-12, 0, "peak ceiling the limiter holds"),
    "loudness.limiter": (0, 1, "look-ahead limiter on/off"),
    "loudness.limiter_lookahead_ms": (0.5, 30, "limiter look-ahead"),
    "loudness.limiter_release_ms": (10, 1000, "limiter release"),
    "loudness.true_peak": (0, 1, "measure peaks 4x oversampled (true peak) instead of sample peak"),
}


def new_config():
    return copy.deepcopy(DEFAULTS)


def deep_merge(base, over):
    for k, v in over.items():
        if isinstance(v, dict) and isinstance(base.get(k), dict):
            deep_merge(base[k], v)
        else:
            base[k] = v
    return base


def coerce_like(default, text):
    if isinstance(default, bool):
        if isinstance(text, bool):
            return text
        return str(text).strip().lower() in ("1", "true", "yes", "on", "y")
    if isinstance(default, int):
        return int(round(float(text)))
    if isinstance(default, float):
        return float(text)
    return str(text)


def set_param(cfg, dotted, value):
    stage, _, key = dotted.partition(".")
    if stage not in DEFAULTS or key not in DEFAULTS[stage]:
        raise KeyError(f"unknown parameter {dotted!r}")
    cfg.setdefault(stage, {})[key] = coerce_like(DEFAULTS[stage][key], value)


def iter_params():
    for stage, block in DEFAULTS.items():
        for key in block:
            yield f"{stage}.{key}"


# ------------------------------------------------------------------ file i/o

def have_ffmpeg():
    return shutil.which("ffmpeg") is not None


def _decode_ffmpeg(path, sr):
    out = subprocess.run(
        ["ffmpeg", "-v", "error", "-i", path, "-ac", "1", "-ar", str(sr), "-f", "f32le", "-"],
        capture_output=True, check=True)
    return np.frombuffer(out.stdout, dtype="<f4").astype(np.float64)


def load_audio(path, sr=SR, decoder="auto"):
    """Mono float64 at `sr`."""
    if decoder == "ffmpeg":
        return _decode_ffmpeg(path, sr)
    try:
        import soundfile as sf
        x, fs = sf.read(path, dtype="float64", always_2d=True)
        x = x.mean(axis=1)
    except Exception:
        if decoder == "soundfile" or not have_ffmpeg():
            raise
        return _decode_ffmpeg(path, sr)
    if fs != sr:
        g = math.gcd(int(fs), int(sr))
        x = signal.resample_poly(x, sr // g, int(fs) // g)
    return np.ascontiguousarray(x, dtype=np.float64)


def save_audio(path, x, sr=SR, fmt="ogg", ogg_quality=6.0):
    os.makedirs(os.path.dirname(os.path.abspath(path)) or ".", exist_ok=True)
    x = np.clip(np.asarray(x, dtype=np.float32), -1.0, 1.0)
    if fmt in ("wav", "flac"):
        import soundfile as sf
        sf.write(path, x, sr, subtype="PCM_16")
        return path
    if not have_ffmpeg():
        import soundfile as sf
        sf.write(path, x, sr, format="OGG", subtype="VORBIS")
        return path
    p = subprocess.Popen(
        ["ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ar", str(sr), "-ac", "1", "-i", "-",
         "-c:a", "libvorbis", "-q:a", str(ogg_quality), path],
        stdin=subprocess.PIPE)
    p.communicate(x.tobytes())
    if p.returncode != 0:
        raise RuntimeError(f"ffmpeg failed encoding {path}")
    return path


AUDIO_EXTS = (".wav", ".mp3", ".ogg", ".flac", ".m4a", ".aiff", ".aif", ".opus", ".wma")


def expand_inputs(patterns):
    files = []
    for pat in patterns:
        if os.path.isdir(pat):
            for name in sorted(os.listdir(pat)):
                if name.lower().endswith(AUDIO_EXTS):
                    files.append(os.path.join(pat, name))
        elif any(c in pat for c in "*?["):
            files.extend(sorted(globmod.glob(pat, recursive=True)))
        else:
            if not os.path.isfile(pat):
                print(f"warning: no such file {pat}", file=sys.stderr)
            files.append(pat)
    seen, out = set(), []
    for f in files:
        k = os.path.abspath(f).lower()
        if k not in seen and os.path.isfile(f):
            seen.add(k)
            out.append(f)
    return out


def natural_key(path):
    stem = os.path.splitext(os.path.basename(path))[0]
    parts, buf = [], ""
    for ch in stem:
        if ch.isdigit():
            buf += ch
        else:
            if buf:
                parts.append((1, int(buf), ""))
                buf = ""
            parts.append((0, 0, ch.lower()))
    if buf:
        parts.append((1, int(buf), ""))
    return parts


# --------------------------------------------------------------------- STFT

def _win(n):
    return np.hanning(n + 1)[:-1]


def stft(x, nfft, hop):
    win = _win(nfft)
    pad = nfft
    xp = np.concatenate([np.zeros(pad), x, np.zeros(pad + nfft)])
    nframes = 1 + (len(xp) - nfft) // hop
    idx = np.arange(nfft)[None, :] + hop * np.arange(nframes)[:, None]
    frames = xp[idx] * win
    return np.fft.rfft(frames, axis=1).T, pad


def istft(Z, nfft, hop, pad, length):
    win = _win(nfft)
    frames = np.fft.irfft(Z.T, n=nfft, axis=1) * win
    total = (frames.shape[0] - 1) * hop + nfft
    out = np.zeros(total)
    wsum = np.zeros(total)
    w2 = win * win
    for i in range(frames.shape[0]):
        s = i * hop
        out[s:s + nfft] += frames[i]
        wsum[s:s + nfft] += w2
    out /= np.maximum(wsum, 1e-9)
    return out[pad:pad + length]


def calibrated_power(Z, nfft):
    """|Z|^2 scaled so that summing over bins gives the frame mean-square (dBFS-compatible)."""
    win = _win(nfft)
    P = np.abs(Z) ** 2 / (nfft * nfft * (win * win).mean())
    P[1:-1] *= 2.0
    return P


def speech_mask(P, drop_db=35.0):
    """Frames carrying speech: within `drop_db` of the loudest frame."""
    e = 10 * np.log10(np.maximum(P.sum(axis=0), 1e-20))
    m = e > (e.max() - drop_db)
    if m.sum() < 4:
        m = e > np.percentile(e, 80)
    return m, e


def smooth_over_freq(G, freqs, span_hz):
    if span_hz <= 0:
        return G
    df = freqs[1] - freqs[0]
    k = max(1, int(round(span_hz / df)))
    if k < 2:
        return G
    return ndimage.uniform_filter1d(G, size=k, axis=0, mode="nearest")


# --------------------------------------------------------------- measurement

def _k_filter(x, fs):
    f0, G, Q = 1681.974450955533, 3.999843853973347, 0.7071752369554196
    K = math.tan(math.pi * f0 / fs)
    Vh = 10 ** (G / 20.0)
    Vb = Vh ** 0.4996667741545416
    a0 = 1.0 + K / Q + K * K
    b = np.array([(Vh + Vb * K / Q + K * K) / a0, 2.0 * (K * K - Vh) / a0,
                  (Vh - Vb * K / Q + K * K) / a0])
    a = np.array([1.0, 2.0 * (K * K - 1.0) / a0, (1.0 - K / Q + K * K) / a0])
    y = signal.lfilter(b, a, x)
    f0, Q = 38.13547087602444, 0.5003270373238773
    K = math.tan(math.pi * f0 / fs)
    d = 1.0 + K / Q + K * K
    b2 = np.array([1.0, -2.0, 1.0])
    a2 = np.array([1.0, 2.0 * (K * K - 1.0) / d, (1.0 - K / Q + K * K) / d])
    return signal.lfilter(b2, a2, y)


def integrated_lufs(x, fs=SR):
    """ITU-R BS.1770-4 integrated loudness, mono."""
    y = _k_filter(np.asarray(x, dtype=np.float64), fs)
    T, H = int(0.4 * fs), int(0.1 * fs)
    if len(y) < T:
        return float("-inf")
    n = 1 + (len(y) - T) // H
    idx = np.arange(T)[None, :] + H * np.arange(n)[:, None]
    p = (y[idx] ** 2).mean(axis=1)
    l = -0.691 + 10 * np.log10(np.maximum(p, 1e-20))
    m = l > -70.0
    if not m.any():
        return float("-inf")
    rel = -0.691 + 10 * np.log10(p[m].mean()) - 10.0
    m2 = m & (l > rel)
    if not m2.any():
        return float("-inf")
    return float(-0.691 + 10 * np.log10(p[m2].mean()))


def peak_db(x, true_peak=True):
    a = np.abs(np.asarray(x, dtype=np.float64))
    if true_peak and len(x) > 16:
        a = np.abs(signal.resample_poly(x, 4, 1))
    return float(20 * np.log10(max(a.max(), 1e-12)))


def analyse(x, fs=SR, nfft=2048):
    """LUFS / peak / speech LTAS / noise-floor LTAS for one signal."""
    hop = nfft // 4
    Z, _ = stft(x, nfft, hop)
    P = calibrated_power(Z, nfft)
    m, e = speech_mask(P)
    quiet = e < np.percentile(e, 15)
    if quiet.sum() < 3:
        quiet = e <= np.percentile(e, 15)
    noise = P[:, quiet].mean(axis=1) if quiet.any() else np.full(P.shape[0], 1e-20)
    return {
        "lufs": integrated_lufs(x, fs),
        "peak_db": peak_db(x, False),
        "true_peak_db": peak_db(x, True),
        "ltas_db": (10 * np.log10(np.maximum(P[:, m].mean(axis=1), 1e-20))).tolist(),
        "noise_db": (10 * np.log10(np.maximum(noise, 1e-20))).tolist(),
        "noise_rms_db": float(10 * np.log10(max(noise.sum(), 1e-20))),
        "duration": len(x) / fs,
        "nfft": nfft,
        "sample_rate": fs,
    }


# ------------------------------------------------------------------- filters

def _biquad_peaking(fs, f0, gain_db, q):
    A = 10 ** (gain_db / 40.0)
    w = 2 * math.pi * f0 / fs
    alpha = math.sin(w) / (2 * q)
    cw = math.cos(w)
    b = [1 + alpha * A, -2 * cw, 1 - alpha * A]
    a = [1 + alpha / A, -2 * cw, 1 - alpha / A]
    return np.array(b) / a[0], np.array(a) / a[0]


def _biquad_shelf(fs, f0, gain_db, low, slope=0.9):
    A = 10 ** (gain_db / 40.0)
    w = 2 * math.pi * f0 / fs
    cw, sw = math.cos(w), math.sin(w)
    alpha = sw / 2 * math.sqrt((A + 1 / A) * (1 / slope - 1) + 2)
    tsa = 2 * math.sqrt(A) * alpha
    if low:
        b = [A * ((A + 1) - (A - 1) * cw + tsa),
             2 * A * ((A - 1) - (A + 1) * cw),
             A * ((A + 1) - (A - 1) * cw - tsa)]
        a = [(A + 1) + (A - 1) * cw + tsa,
             -2 * ((A - 1) + (A + 1) * cw),
             (A + 1) + (A - 1) * cw - tsa]
    else:
        b = [A * ((A + 1) + (A - 1) * cw + tsa),
             -2 * A * ((A - 1) + (A + 1) * cw),
             A * ((A + 1) + (A - 1) * cw - tsa)]
        a = [(A + 1) - (A - 1) * cw + tsa,
             2 * ((A - 1) - (A + 1) * cw),
             (A + 1) - (A - 1) * cw - tsa]
    return np.array(b) / a[0], np.array(a) / a[0]


def apply_biquad(x, ba):
    return signal.lfilter(ba[0], ba[1], x)


# -------------------------------------------------------------------- stages

def stage_prep(x, cfg, fs=SR):
    p = cfg["prep"]
    if not p["enabled"]:
        return x
    if p["dc_offset"]:
        x = x - x.mean()
    ny = fs / 2.0
    if p["highpass_hz"] > 0:
        sos = signal.butter(int(p["highpass_order"]), min(p["highpass_hz"], ny * 0.98) / ny,
                            btype="highpass", output="sos")
        x = signal.sosfilt(sos, x)
    if p["lowpass_hz"] > 0 and p["lowpass_hz"] < ny * 0.99:
        sos = signal.butter(6, p["lowpass_hz"] / ny, btype="lowpass", output="sos")
        x = signal.sosfilt(sos, x)
    if p["hum_hz"] > 0:
        for h in range(1, int(p["hum_harmonics"]) + 1):
            f0 = p["hum_hz"] * h
            if f0 >= ny * 0.95:
                break
            b, a = signal.iirnotch(f0 / ny, p["hum_q"])
            x = signal.lfilter(b, a, x)
    return x


def noise_profile(x, cfg, fs=SR):
    """Per-bin noise power estimate for the denoiser."""
    d = cfg["denoise"]
    nfft, hop = int(d["nfft"]), int(d["nfft"]) // int(d["overlap"])
    if d["noise_file"]:
        nx = load_audio(d["noise_file"], fs, cfg["io"]["decoder"])
        Zn, _ = stft(nx, nfft, hop)
        return (np.abs(Zn) ** 2).mean(axis=1)
    if d["noise_start"] >= 0 and d["noise_end"] > d["noise_start"]:
        a, b = int(d["noise_start"] * fs), int(d["noise_end"] * fs)
        seg = x[a:min(b, len(x))]
        if len(seg) > nfft * 2:
            Zn, _ = stft(seg, nfft, hop)
            return (np.abs(Zn) ** 2).mean(axis=1)
    Z, _ = stft(x, nfft, hop)
    P = np.abs(Z) ** 2
    return np.percentile(P, d["noise_percentile"], axis=1)


def stage_denoise(x, cfg, fs=SR, noise_pow=None):
    """Decision-directed Wiener suppression against a learned noise profile."""
    d = cfg["denoise"]
    if not d["enabled"] or d["strength"] <= 0:
        return x
    nfft, hop = int(d["nfft"]), int(d["nfft"]) // int(d["overlap"])
    Z, pad = stft(x, nfft, hop)
    P = np.abs(Z) ** 2
    if noise_pow is None:
        noise_pow = noise_profile(x, cfg, fs)
    lam = np.maximum(noise_pow * d["oversubtract"], 1e-20)[:, None]

    gmin = 10 ** (-d["reduction_db"] / 20.0)
    alpha = d["dd_alpha"]
    gamma = P / lam
    G = np.empty_like(gamma)
    prev = np.maximum(gamma[:, 0] - 1.0, 0.0)
    prev = prev / (prev + 1.0)
    for t in range(gamma.shape[1]):
        inst = np.maximum(gamma[:, t] - 1.0, 0.0)
        xi = alpha * (prev ** 2) * (gamma[:, t - 1] if t else gamma[:, 0]) + (1 - alpha) * inst
        g = xi / (xi + 1.0)
        G[:, t] = g
        prev = g
    G = np.maximum(G, gmin)
    G = smooth_over_freq(G, np.fft.rfftfreq(nfft, 1 / fs), d["freq_smooth_hz"])
    ts = d["time_smooth"]
    if ts > 0:
        k = max(1, int(round(1 / (1 - min(ts, 0.94)))))
        G = ndimage.uniform_filter1d(G, size=k, axis=1, mode="nearest")
    G = 1.0 - d["strength"] * (1.0 - np.clip(G, 0.0, 1.0))
    return istft(Z * G, nfft, hop, pad, len(x))


def _wpe(Z, taps, delay, iterations, chunk=48):
    """Single-channel weighted prediction error dereverberation."""
    F, T = Z.shape
    Y = Z.copy()
    if T <= delay + taps + 4:
        return Y
    for _ in range(int(iterations)):
        for f0 in range(0, F, chunk):
            f1 = min(F, f0 + chunk)
            Zb = Z[f0:f1]
            Yb = Y[f0:f1]
            nb = f1 - f0
            Xd = np.zeros((nb, T, taps), dtype=np.complex128)
            for k in range(taps):
                dl = delay + k
                Xd[:, dl:, k] = Zb[:, :T - dl]
            pw = np.abs(Yb) ** 2
            floor = np.maximum(pw.mean(axis=1, keepdims=True) * 1e-6, 1e-12)
            inv = 1.0 / np.maximum(pw, floor)
            W = Xd * inv[:, :, None]
            R = np.einsum("ftk,ftl->fkl", W, Xd.conj())
            r = np.einsum("ftk,ft->fk", W, Zb.conj())
            tr = np.einsum("fkk->f", R).real / taps
            R += (1e-5 * np.maximum(tr, 1e-12) + 1e-12)[:, None, None] * np.eye(taps)
            g = np.linalg.solve(R, r[:, :, None])[:, :, 0]
            Y[f0:f1] = Zb - np.einsum("fk,ftk->ft", g.conj(), Xd)
    return Y


def _late_suppress(Z, cfg, fs, nfft, hop):
    d = cfg["dereverb"]
    P = np.abs(Z) ** 2
    frame_s = hop / fs
    delta = max(1, int(round((d["late_delay_ms"] / 1000.0) / frame_s)))
    decay = 3.0 * math.log(10.0) / max(d["late_rt60"], 0.05)
    kappa = math.exp(-2.0 * decay * delta * frame_s)
    Plate = np.zeros_like(P)
    Plate[:, delta:] = kappa * P[:, :-delta]
    floor = 10 ** (d["late_floor_db"] / 10.0)
    G = np.sqrt(np.maximum(1.0 - d["late_oversubtract"] * Plate / np.maximum(P, 1e-20), floor))
    G = smooth_over_freq(G, np.fft.rfftfreq(nfft, 1 / fs), 150.0)
    return Z * G


def stage_dereverb(x, cfg, fs=SR):
    d = cfg["dereverb"]
    if not d["enabled"] or d["mix"] <= 0:
        return x
    y = x
    if d["method"] in ("wpe", "both"):
        nfft = int(d["wpe_nfft"])
        hop = nfft // 4
        Z, pad = stft(y, nfft, hop)
        Zw = _wpe(Z, int(d["wpe_taps"]), int(d["wpe_delay"]), int(d["wpe_iterations"]))
        y = istft(Zw, nfft, hop, pad, len(x))
    if d["method"] in ("late", "both"):
        nfft = int(d["late_nfft"])
        hop = nfft // 4
        Z, pad = stft(y, nfft, hop)
        y = istft(_late_suppress(Z, cfg, fs, nfft, hop), nfft, hop, pad, len(x))
    return (1.0 - d["mix"]) * x + d["mix"] * y


def stage_deess(x, cfg, fs=SR):
    """STFT-domain dynamic sibilance control - no band-split phase artefacts."""
    d = cfg["deess"]
    if not d["enabled"] or d["max_reduction_db"] <= 0:
        return x
    nfft, hop = 1024, 256
    Z, pad = stft(x, nfft, hop)
    freqs = np.fft.rfftfreq(nfft, 1 / fs)
    band = (freqs >= d["low_hz"]) & (freqs <= d["high_hz"])
    if not band.any():
        return x
    P = calibrated_power(Z, nfft)
    band_db = 10 * np.log10(np.maximum(P[band].sum(axis=0), 1e-20))
    active, _ = speech_mask(P)
    if d["auto_threshold"] and active.sum() > 4:
        thr = np.percentile(band_db[active], d["auto_percentile"])
    else:
        thr = d["threshold_db"]
    over = np.maximum(band_db - thr, 0.0)
    red = np.minimum(over * (1.0 - 1.0 / max(d["ratio"], 1.0)), d["max_reduction_db"])
    frame_ms = hop / fs * 1000.0
    ka = max(1, int(round(d["attack_ms"] / frame_ms)))
    kr = max(1, int(round(d["release_ms"] / frame_ms)))
    sm = np.empty_like(red)
    cur = 0.0
    aa = math.exp(-1.0 / ka)
    ar = math.exp(-1.0 / kr)
    for i, v in enumerate(red):
        c = aa if v > cur else ar
        cur = c * cur + (1 - c) * v
        sm[i] = cur
    shape = np.zeros(len(freqs))
    shape[band] = 1.0
    shape = ndimage.uniform_filter1d(shape, size=5, mode="nearest")
    G = 10 ** (-(sm[None, :] * shape[:, None]) / 20.0)
    return istft(Z * G, nfft, hop, pad, len(x))


def stage_eq(x, cfg, fs=SR):
    e = cfg["eq"]
    if not e["enabled"]:
        return x
    if abs(e["low_shelf_db"]) > 0.01:
        x = apply_biquad(x, _biquad_shelf(fs, e["low_shelf_hz"], e["low_shelf_db"], True))
    if abs(e["bell1_db"]) > 0.01:
        x = apply_biquad(x, _biquad_peaking(fs, e["bell1_hz"], e["bell1_db"], e["bell1_q"]))
    if abs(e["bell2_db"]) > 0.01:
        x = apply_biquad(x, _biquad_peaking(fs, e["bell2_hz"], e["bell2_db"], e["bell2_q"]))
    if abs(e["high_shelf_db"]) > 0.01:
        x = apply_biquad(x, _biquad_shelf(fs, e["high_shelf_hz"], e["high_shelf_db"], False))
    if abs(e["tilt_db"]) > 0.01:
        x = apply_biquad(x, _biquad_shelf(fs, 900.0, -e["tilt_db"] / 2.0, True))
        x = apply_biquad(x, _biquad_shelf(fs, 900.0, e["tilt_db"] / 2.0, False))
    return x


def _log_smooth(freqs, curve_db, octaves):
    if octaves <= 0:
        return curve_db
    lo = max(freqs[1], 20.0)
    hi = freqs[-1]
    n = 512
    grid = np.geomspace(lo, hi, n)
    v = np.interp(grid, freqs, curve_db)
    per_oct = n / math.log2(hi / lo)
    k = max(1, int(round(octaves * per_oct)))
    v = ndimage.uniform_filter1d(v, size=k, mode="nearest")
    return np.interp(freqs, grid, v)


def match_curve(src_ltas_db, ref_ltas_db, freqs, cfg):
    """Correction curve in dB that pulls the source LTAS onto the reference LTAS."""
    m = cfg["match"]
    band = (freqs >= 250) & (freqs <= 6000)
    src = np.asarray(src_ltas_db, dtype=np.float64)
    ref = np.asarray(ref_ltas_db, dtype=np.float64)
    src = src - src[band].mean()
    ref = ref - ref[band].mean()
    diff = _log_smooth(freqs, ref - src, m["smooth_octaves"])
    diff = np.clip(diff, -abs(m["max_cut_db"]), abs(m["max_boost_db"])) * m["strength"]
    # fade the curve to flat over one octave beyond each band edge
    f = np.maximum(freqs, 1e-6)
    lo, hi = max(m["low_hz"], 1.0), max(m["high_hz"], 2.0)
    taper = np.ones_like(f)
    below = f < lo
    taper[below] = np.clip(1.0 + np.log2(f[below] / lo), 0.0, 1.0)
    above = f > hi
    taper[above] = np.clip(1.0 - np.log2(f[above] / hi), 0.0, 1.0)
    return diff * taper


def curve_to_fir(curve_db, freqs, taps, fs=SR):
    n = 8192
    grid = np.fft.rfftfreq(n, 1 / fs)
    H = 10 ** (np.interp(grid, freqs, curve_db) / 20.0)
    h = np.fft.irfft(H, n=n)
    h = np.roll(h, n // 2)
    half = int(taps) // 2
    mid = n // 2
    h = h[mid - half: mid + half + 1] * np.hanning(2 * half + 1)
    return h


def stage_match_eq(x, cfg, ref, fs=SR):
    m = cfg["match"]
    if not m["enabled"] or ref is None or m["strength"] <= 0:
        return x, None
    nfft = int(ref.get("nfft", 2048))
    freqs = np.fft.rfftfreq(nfft, 1 / fs)
    src = analyse(x, fs, nfft)
    curve = match_curve(src["ltas_db"], ref["ltas_db"], freqs, cfg)
    if np.abs(curve).max() < 0.05:
        return x, curve
    h = curve_to_fir(curve, freqs, int(m["fir_taps"]) | 1, fs)
    return signal.fftconvolve(x, h, mode="same"), curve


def _control_env(x, fs, block, mode="rms"):
    n = len(x) // block
    if n < 1:
        return np.atleast_1d(np.sqrt((x ** 2).mean()) if len(x) else 0.0), 1
    b = x[:n * block].reshape(n, block)
    return (np.sqrt((b ** 2).mean(axis=1)) if mode == "rms" else np.abs(b).max(axis=1)), n


def _expand_gain(g_ctrl, block, length):
    y = np.repeat(g_ctrl, block)
    if len(y) < length:
        y = np.concatenate([y, np.full(length - len(y), y[-1] if len(y) else 1.0)])
    return ndimage.uniform_filter1d(y[:length], size=min(block * 2 + 1, max(3, length // 2 * 2 + 1)),
                                    mode="nearest")


def stage_gate(x, cfg, fs=SR, noise_rms_db=None):
    g = cfg["gate"]
    if not g["enabled"] or g["range_db"] <= 0:
        return x
    block = max(1, int(fs * 0.002))
    env, n = _control_env(x, fs, block)
    env_db = 20 * np.log10(np.maximum(env, 1e-12))
    if g["auto_threshold"]:
        floor = noise_rms_db if noise_rms_db is not None else np.percentile(env_db, 10)
        thr = floor + g["above_floor_db"]
        thr = min(thr, np.percentile(env_db, 95) - 12.0)
    else:
        thr = g["threshold_db"]
    ctrl_ms = block / fs * 1000.0
    ka = max(1, int(round(g["attack_ms"] / ctrl_ms)))
    kh = max(0, int(round(g["hold_ms"] / ctrl_ms)))
    kr = max(1, int(round(g["release_ms"] / ctrl_ms)))
    target = np.where(env_db > thr, 0.0, -g["range_db"])
    if kh:
        target = ndimage.maximum_filter1d(target, size=2 * kh + 1, mode="nearest")
    aa, ar = math.exp(-1.0 / ka), math.exp(-1.0 / kr)
    out = np.empty_like(target)
    cur = target[0]
    for i, v in enumerate(target):
        c = aa if v > cur else ar
        cur = c * cur + (1 - c) * v
        out[i] = cur
    return x * _expand_gain(10 ** (out / 20.0), block, len(x))


def stage_compress(x, cfg, fs=SR):
    c = cfg["compress"]
    if not c["enabled"] or c["ratio"] <= 1.0:
        return x
    block = max(1, int(fs * 0.001))
    env, n = _control_env(x, fs, block)
    env_db = 20 * np.log10(np.maximum(env, 1e-12))
    thr, ratio, knee = c["threshold_db"], c["ratio"], max(c["knee_db"], 1e-6)
    over = env_db - thr
    out_db = np.where(
        over <= -knee / 2, env_db,
        np.where(over >= knee / 2, thr + over / ratio,
                 env_db + (1 / ratio - 1) * (over + knee / 2) ** 2 / (2 * knee)))
    red = out_db - env_db
    ctrl_ms = block / fs * 1000.0
    aa = math.exp(-1.0 / max(1, c["attack_ms"] / ctrl_ms))
    ar = math.exp(-1.0 / max(1, c["release_ms"] / ctrl_ms))
    sm = np.empty_like(red)
    cur = 0.0
    for i, v in enumerate(red):
        co = aa if v < cur else ar
        cur = co * cur + (1 - co) * v
        sm[i] = cur
    y = x * _expand_gain(10 ** (sm / 20.0), block, len(x))
    makeup = c["makeup_db"]
    if c["makeup_auto"]:
        a, b = integrated_lufs(x, fs), integrated_lufs(y, fs)
        if math.isfinite(a) and math.isfinite(b):
            makeup += a - b
    return y * (10 ** (makeup / 20.0))


def stage_trim(x, cfg, fs=SR, noise_rms_db=None):
    t = cfg["trim"]
    if not t["enabled"]:
        return x, 0, len(x)
    block = max(1, int(fs * 0.005))
    env, n = _control_env(x, fs, block)
    env_db = 20 * np.log10(np.maximum(env, 1e-12))
    floor = noise_rms_db if noise_rms_db is not None else np.percentile(env_db, 10)
    thr = max(floor + t["above_floor_db"], env_db.max() - 45.0)
    voiced = np.where(env_db > thr)[0]
    if len(voiced) == 0:
        return x, 0, len(x)
    a = max(0, voiced[0] * block - int(t["head_pad_ms"] / 1000.0 * fs))
    b = min(len(x), (voiced[-1] + 1) * block + int(t["tail_pad_ms"] / 1000.0 * fs))
    y = x[a:b].copy()
    f = int(t["fade_ms"] / 1000.0 * fs)
    if f > 1 and len(y) > 2 * f:
        ramp = np.linspace(0, 1, f) ** 2
        y[:f] *= ramp
        y[-f:] *= ramp[::-1]
    return y, a, b


def stage_limiter(x, cfg, fs=SR):
    l = cfg["loudness"]
    ceiling = 10 ** (l["peak_ceiling_db"] / 20.0)
    if not l["limiter"]:
        return np.clip(x, -ceiling, ceiling)
    look = max(1, int(l["limiter_lookahead_ms"] / 1000.0 * fs))
    a = np.abs(x)
    if l["true_peak"]:
        up = np.abs(signal.resample_poly(x, 4, 1))
        a = np.maximum(a, ndimage.maximum_filter1d(up, size=4, mode="nearest")[:len(x) * 4:4][:len(x)])
    need = np.minimum(1.0, ceiling / np.maximum(a, 1e-12))
    need = ndimage.minimum_filter1d(need, size=2 * look + 1, mode="nearest")
    kr = max(1, int(l["limiter_release_ms"] / 1000.0 * fs))
    alpha = math.exp(-1.0 / kr)
    released = signal.lfilter([1 - alpha], [1.0, -alpha], need, zi=[need[0] * alpha])[0]
    g = ndimage.uniform_filter1d(np.minimum(need, released), size=max(3, look | 1), mode="nearest")
    return np.clip(x * np.minimum(g, need), -ceiling, ceiling)


def stage_loudness(x, cfg, fs=SR):
    l = cfg["loudness"]
    if not l["enabled"]:
        return stage_limiter(x, cfg, fs) if l["limiter"] else x
    for _ in range(3):
        cur = integrated_lufs(x, fs)
        if not math.isfinite(cur):
            break
        delta = l["target_lufs"] - cur
        if abs(delta) < 0.05:
            break
        x = x * (10 ** (delta / 20.0))
    return stage_limiter(x, cfg, fs)


def stage_add_room_tone(x, cfg, ref, fs=SR):
    m = cfg["match"]
    if not m["match_noise_floor"] or ref is None:
        return x
    nfft = int(ref.get("nfft", 2048))
    freqs = np.fft.rfftfreq(nfft, 1 / fs)
    shape_db = np.asarray(ref["noise_db"], dtype=np.float64)
    h = curve_to_fir(shape_db - shape_db.max(), freqs, 1023, fs)
    n = signal.fftconvolve(np.random.default_rng(0).normal(0, 1, len(x)), h, mode="same")
    rms = math.sqrt(max((n ** 2).mean(), 1e-30))
    target = 10 ** ((ref["noise_rms_db"] + m["noise_floor_offset_db"]) / 20.0)
    return x + n * (target / rms)


# ------------------------------------------------------------------ pipeline

def process(x, cfg, ref=None, fs=SR, stop_after=None):
    """Run the chain.  Returns (audio, info dict)."""
    info = {}
    src0 = analyse(x, fs)
    info["in_lufs"] = src0["lufs"]
    info["in_peak_db"] = src0["true_peak_db"]
    info["in_noise_db"] = src0["noise_rms_db"]
    info["in_duration"] = len(x) / fs

    order = ["prep", "denoise", "dereverb", "deess", "eq", "match", "gate",
             "compress", "trim", "loudness", "roomtone"]
    for name in order:
        if name == "prep":
            x = stage_prep(x, cfg, fs)
        elif name == "denoise":
            x = stage_denoise(x, cfg, fs)
        elif name == "dereverb":
            x = stage_dereverb(x, cfg, fs)
        elif name == "deess":
            x = stage_deess(x, cfg, fs)
        elif name == "eq":
            x = stage_eq(x, cfg, fs)
        elif name == "match":
            x, curve = stage_match_eq(x, cfg, ref, fs)
            info["match_curve"] = curve
        elif name == "gate":
            x = stage_gate(x, cfg, fs, analyse(x, fs)["noise_rms_db"])
        elif name == "compress":
            x = stage_compress(x, cfg, fs)
        elif name == "trim":
            x, a, b = stage_trim(x, cfg, fs, analyse(x, fs)["noise_rms_db"])
            info["trim_head_s"] = a / fs
        elif name == "loudness":
            if ref is not None and cfg["match"]["enabled"] and cfg["match"]["match_loudness"]:
                cfg = deep_merge(copy.deepcopy(cfg), {"loudness": {"target_lufs": ref["lufs"]}})
            x = stage_loudness(x, cfg, fs)
        elif name == "roomtone":
            x = stage_add_room_tone(x, cfg, ref, fs)
        if stop_after and name == stop_after:
            break

    out = analyse(x, fs)
    info["out_lufs"] = out["lufs"]
    info["out_peak_db"] = out["true_peak_db"]
    info["out_noise_db"] = out["noise_rms_db"]
    info["out_duration"] = len(x) / fs
    info["target_lufs"] = cfg["loudness"]["target_lufs"]
    return x, info


# ----------------------------------------------------------------- reference

def build_reference(paths, cfg=None, nfft=2048, fs=SR, max_files=400, name=""):
    """Average LUFS / peak / LTAS / noise spectrum over one or many vanilla lines."""
    files = expand_inputs(paths if isinstance(paths, (list, tuple)) else [paths])
    if not files:
        raise SystemExit(f"no reference audio matched {paths!r}")
    if len(files) > max_files:
        rng = np.random.default_rng(0)
        files = [files[i] for i in sorted(rng.choice(len(files), max_files, replace=False))]
    ltas, noise, lufs, peaks, tpeaks, nrms = [], [], [], [], [], []
    dec = (cfg or DEFAULTS)["io"]["decoder"]
    for p in files:
        try:
            x = load_audio(p, fs, dec)
        except Exception:
            continue
        if len(x) < fs * 0.3 or not np.isfinite(x).all():
            continue
        a = analyse(x, fs, nfft)
        if not math.isfinite(a["lufs"]):
            continue
        ltas.append(a["ltas_db"])
        noise.append(a["noise_db"])
        nrms.append(a["noise_rms_db"])
        lufs.append(a["lufs"])
        peaks.append(a["peak_db"])
        tpeaks.append(a["true_peak_db"])
    if not ltas:
        raise SystemExit("reference files could not be analysed")
    return {
        "name": name or (os.path.basename(files[0]) if len(files) == 1 else f"{len(ltas)} files"),
        "n_files": len(ltas),
        "sample_rate": fs,
        "nfft": nfft,
        "lufs": float(np.median(lufs)),
        "lufs_mean": float(np.mean(lufs)),
        "peak_db": float(np.median(peaks)),
        "true_peak_db": float(np.median(tpeaks)),
        "noise_rms_db": float(np.median(nrms)),
        "ltas_db": np.mean(ltas, axis=0).tolist(),
        "noise_db": np.mean(noise, axis=0).tolist(),
    }


def load_reference(spec, cfg=None, max_files=400):
    if not spec:
        return None
    if isinstance(spec, str) and spec.lower().endswith(".json") and os.path.isfile(spec):
        with open(spec, "r", encoding="utf-8") as fh:
            return json.load(fh)
    return build_reference(spec, cfg, max_files=max_files)


# ---------------------------------------------------------------------- CLI

def fmt_row(vals, widths):
    return "".join(str(v).ljust(w) for v, w in zip(vals, widths))


def run_batch(files, cfg, ref, outdir, quiet=False, dry_run=False):
    fs = int(cfg["io"]["sample_rate"])
    fmt = cfg["io"]["format"]
    prefixes = [p.strip() for p in cfg["io"]["prefixes"].split(",") if p.strip()]
    rows = []
    for i, path in enumerate(files, 1):
        stem = os.path.splitext(os.path.basename(path))[0]
        x = load_audio(path, fs, cfg["io"]["decoder"])
        y, info = process(x, cfg, ref, fs)
        name = cfg["io"]["name_template"].format(stem=stem, index=i)
        written = []
        if not dry_run:
            targets = [f"{p.rstrip('_')}_{name}" for p in prefixes] or [name]
            for t in targets:
                written.append(save_audio(os.path.join(outdir, f"{t}.{fmt}"), y, fs, fmt,
                                          cfg["io"]["ogg_quality"]))
            if cfg["io"]["write_wav_copy"]:
                save_audio(os.path.join(outdir, f"{name}.wav"), y, fs, "wav")
        rows.append({
            "file": os.path.basename(path), "out": name,
            "in_lufs": info["in_lufs"], "out_lufs": info["out_lufs"],
            "in_peak": info["in_peak_db"], "out_peak": info["out_peak_db"],
            "in_noise": info["in_noise_db"], "out_noise": info["out_noise_db"],
            "in_dur": info["in_duration"], "out_dur": info["out_duration"],
        })
        if not quiet:
            r = rows[-1]
            print(f"[{i:>3}/{len(files)}] {r['file']:<24} "
                  f"LUFS {r['in_lufs']:7.1f} -> {r['out_lufs']:6.1f}   "
                  f"peak {r['in_peak']:6.1f} -> {r['out_peak']:5.1f}   "
                  f"floor {r['in_noise']:6.1f} -> {r['out_noise']:6.1f}   "
                  f"{r['in_dur']:5.2f}s -> {r['out_dur']:5.2f}s")
    return rows


def main(argv=None):
    ap = argparse.ArgumentParser(
        prog="voice_master",
        description="Denoise, dereverb and master voice lines to match KCD2 vanilla dialogue.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="examples:\n"
               "  voice_master.py Voicelines -o out --ref references/Voicelines/dialog/**/*.ogg\n"
               "  voice_master.py Voicelines/12.mp3 -o out --set denoise.strength=0.6 --preview\n"
               "  voice_master.py --gui\n")
    ap.add_argument("inputs", nargs="*", help="files, folders or globs to process")
    ap.add_argument("-o", "--out", default=None, help="output folder (default: <input>/mastered)")
    ap.add_argument("--ref", default=None,
                    help="vanilla line(s) to match: file, folder, glob, or a saved profile .json")
    ap.add_argument("--ref-samples", type=int, default=400, help="cap on reference files analysed")
    ap.add_argument("--no-profile", action="store_true",
                    help="ignore the bundled vanilla_profile.json when --ref is absent")
    ap.add_argument("--preset", default=None, help="JSON preset to load")
    ap.add_argument("--save-preset", default=None, help="write the effective settings here and exit")
    ap.add_argument("--set", dest="sets", action="append", default=[],
                    metavar="stage.key=value", help="override one parameter (repeatable)")
    ap.add_argument("--list-params", action="store_true", help="print every parameter and exit")
    ap.add_argument("--build-profile", nargs="+", metavar="GLOB",
                    help="analyse these files into a reference profile .json and exit")
    ap.add_argument("--profile-out", default=DEFAULT_PROFILE, help="where --build-profile writes")
    ap.add_argument("--analyse", action="store_true", help="measure the inputs and exit")
    ap.add_argument("--report", default=None, help="write a CSV of before/after numbers")
    ap.add_argument("--dry-run", action="store_true", help="process but write nothing")
    ap.add_argument("--limit", type=int, default=0, help="only the first N inputs")
    ap.add_argument("--gui", action="store_true", help="open the slider GUI")
    ap.add_argument("-q", "--quiet", action="store_true")
    args = ap.parse_args(argv)

    if args.list_params:
        for key in iter_params():
            stage, _, k = key.partition(".")
            lo, hi, doc = PARAM_META.get(key, (0, 0, ""))
            rng = f"[{lo}..{hi}]" if (lo, hi) != (0, 0) else ""
            print(f"  {key:<34} = {DEFAULTS[stage][k]!r:<12} {rng:<16} {doc}")
        return 0

    cfg = new_config()
    if args.preset:
        with open(args.preset, "r", encoding="utf-8") as fh:
            deep_merge(cfg, json.load(fh))
    for s in args.sets:
        if "=" not in s:
            ap.error(f"--set needs stage.key=value, got {s!r}")
        k, _, v = s.partition("=")
        try:
            set_param(cfg, k.strip(), v.strip())
        except KeyError as exc:
            ap.error(str(exc))

    if args.save_preset:
        with open(args.save_preset, "w", encoding="utf-8") as fh:
            json.dump(cfg, fh, indent=2)
        print(f"wrote {args.save_preset}")
        return 0

    if args.build_profile:
        prof = build_reference(args.build_profile, cfg, max_files=args.ref_samples)
        with open(args.profile_out, "w", encoding="utf-8") as fh:
            json.dump(prof, fh)
        print(f"profile from {prof['n_files']} files -> {args.profile_out}")
        print(f"  LUFS {prof['lufs']:.2f}  peak {prof['peak_db']:.2f}  "
              f"true peak {prof['true_peak_db']:.2f}  floor {prof['noise_rms_db']:.1f}")
        return 0

    if args.gui:
        from voice_master_gui import launch
        return launch(cfg, args)

    files = expand_inputs(args.inputs)
    files.sort(key=natural_key)
    if args.limit:
        files = files[:args.limit]
    if not files:
        ap.error("no input files matched")

    if args.analyse:
        for p in files:
            a = analyse(load_audio(p, int(cfg["io"]["sample_rate"]), cfg["io"]["decoder"]))
            print(f"{os.path.basename(p):<28} {a['duration']:6.2f}s  LUFS {a['lufs']:7.2f}  "
                  f"peak {a['peak_db']:6.2f}  true peak {a['true_peak_db']:6.2f}  "
                  f"floor {a['noise_rms_db']:7.1f}")
        return 0

    ref_spec = args.ref
    if ref_spec is None and not args.no_profile and os.path.isfile(DEFAULT_PROFILE):
        ref_spec = DEFAULT_PROFILE
    ref = load_reference(ref_spec, cfg, args.ref_samples)
    if ref and not args.quiet:
        print(f"reference: {ref['name']} ({ref['n_files']} file(s))  "
              f"LUFS {ref['lufs']:.2f}  peak {ref['peak_db']:.2f}  floor {ref['noise_rms_db']:.1f}")

    outdir = args.out or os.path.join(os.path.dirname(os.path.abspath(files[0])), "mastered")
    if not args.dry_run:
        os.makedirs(outdir, exist_ok=True)
    rows = run_batch(files, cfg, ref, outdir, args.quiet, args.dry_run)

    if args.report:
        import csv
        with open(args.report, "w", newline="", encoding="utf-8") as fh:
            w = csv.DictWriter(fh, fieldnames=list(rows[0].keys()) + ["reference_length"])
            w.writeheader()
            for r in rows:
                r = dict(r)
                r["reference_length"] = int(math.ceil(r["out_dur"]))
                w.writerow(r)
        print(f"wrote {args.report}")

    if not args.quiet and rows:
        print(f"\n{len(rows)} file(s) -> {outdir}")
        print(f"  LUFS spread {min(r['out_lufs'] for r in rows):.2f} .. "
              f"{max(r['out_lufs'] for r in rows):.2f}   "
              f"peak max {max(r['out_peak'] for r in rows):.2f} dB")
        print("  ReferenceLength (ceil seconds): " +
              " ".join(f"{r['out']}={int(math.ceil(r['out_dur']))}" for r in rows[:8]) +
              (" ..." if len(rows) > 8 else ""))
    return 0


if __name__ == "__main__":
    sys.path.insert(0, HERE)
    sys.exit(main())
