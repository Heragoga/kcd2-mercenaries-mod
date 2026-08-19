# Mastering recorded voice lines

`tools/voice_master.py` takes raw takes and makes them sit next to base-game dialogue:
denoise, dereverb, de-ess, EQ, gate, compress, trim, loudness-normalise, encode `.ogg`.
`tools/voice_master_gui.py` is the same engine behind sliders.

Requires `numpy scipy soundfile` (+ `matplotlib` and `sounddevice` for the GUI) and
`ffmpeg` on PATH for `.ogg` encoding.

## Why it is needed

The Aleksej takes shipped as straight mp3 -> ogg transcodes. Measured against 348 random
vanilla dialogue files:

| | source takes | vanilla |
|---|---|---|
| integrated loudness | -26.6 LUFS | -22.3 LUFS |
| true peak | -9.8 dB | -4.2 dB |
| noise floor | -55 to -88 dBFS | -71.8 dBFS |
| LTAS at 100 Hz (re 1 kHz) | +18 dB | +5.5 dB |
| LTAS at 5 kHz (re 1 kHz) | -8 dB | -21 dB |

So: too quiet, far too much proximity bass, too much upper-mid hiss. Broadband RMS tonal
error over 80 Hz - 12 kHz is **8.1 dB before, 2.3 dB after**.

## Everyday use

```bash
python tools/voice_master.py Voicelines -o Voicelines/mastered \
  --ref tools/vanilla_profile_jcom.json \
  --set "io.name_template=jcom_merc_alx_L{stem}" \
  --report Voicelines/mastered/report.csv
```

Sliders, A/B playback and a live spectrum plot against the reference:

```bash
python tools/voice_master.py --gui Voicelines
```

## Picking a reference

`--ref` accepts a single file, a folder, a glob, or a saved profile `.json`. It sets the
loudness target and the tone-match curve.

**Reference choice matters.** LTAS at 100 Hz across vanilla actors: `gand` +2.0 dB,
`tmck` +17.5 dB, `jcom` +8.9 dB, all-actor average +5.5 dB. Matching a bass-light actor
will thin out a bass-heavy voice.

Pick the actor code the files actually ship under - Aleksej's lines are
`jcom_merc_alx_L*.ogg`, so `jcom` is the right target:

```bash
python tools/voice_master.py --build-profile "references/Voicelines/dialog/**/jcom_*.ogg" \
  --ref-samples 300 --profile-out tools/vanilla_profile_jcom.json
```

Two profiles are checked in: `vanilla_profile.json` (348 random lines, the default when
`--ref` is omitted) and `vanilla_profile_jcom.json`. `--no-profile` disables the default.

## Adjusting parameters

Three interchangeable routes, all covering the same ~100 parameters:

```bash
python tools/voice_master.py --list-params              # names, defaults, ranges, one-line help
python tools/voice_master.py in -o out --set denoise.strength=0.6 --set eq.tilt_db=1.5
python tools/voice_master.py --set ... --save-preset mypreset.json
python tools/voice_master.py in -o out --preset mypreset.json
```

The GUI has one tab per stage and the same Save/Load preset buttons.

The knobs worth reaching for first:

| parameter | effect |
|---|---|
| `match.strength` | how much of the measured tone-match curve is applied (0 = none) |
| `match.max_cut_db` | caps the bass cut; lower it if the voice goes thin |
| `denoise.strength`, `denoise.reduction_db` | trade hiss against artefacts |
| `dereverb.method` | `wpe` (best, ~5 s/file), `late` (fast), `both` |
| `dereverb.mix` | dial the dereverb back if it sounds phasey |
| `prep.highpass_hz` | rumble filter, 85 Hz by default |
| `loudness.target_lufs` | overridden by the reference unless `match.match_loudness` is off |
| `trim.head_pad_ms`, `trim.tail_pad_ms` | silence kept around the take |

## Durations and ReferenceLength

Trimming changes file length, and `docs/aleksej.md` / `aleksej_script.md` use per-line
lengths as the `ReferenceLength` of each Skald `<Response>`. The run prints the new
`ceil(seconds)` per file and `--report` writes them to CSV as a `reference_length`
column. Check that column against the script's `len` values after any trim change.

## Notes on the DSP

- Loudness is ITU-R BS.1770-4 integrated, gated, implemented inline - no `pyloudnorm`.
- Denoise is decision-directed Wiener suppression against a per-bin noise profile learned
  from the quietest frames, with the gain curve smoothed across frequency so it does not
  produce musical noise. `denoise.noise_file` or `noise_start`/`noise_end` override the
  learned profile with real room tone.
- Dereverb defaults to single-channel WPE (weighted prediction error); `late` is
  Lebart-style spectral subtraction of the late field, driven by `late_rt60`.
- The tone match is a linear-phase FIR built by frequency-sampling the smoothed,
  clipped difference between the source and reference speech-gated LTAS.
- Analysis STFT power is calibrated so bin sums read as dBFS; the gate and trim
  thresholds are set relative to the measured noise floor in the same units.
