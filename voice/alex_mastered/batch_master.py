#!/usr/bin/env python3
"""
batch_master.py — Batch master .ogg voicelines using Matchering
Usage: python batch_master.py --input ./voicelines --reference ./reference.wav --output ./mastered

Note: Matchering outputs PCM_16 WAV only. This script masters to a temp WAV,
then re-encodes to OGG Vorbis via soundfile, then cleans up the temp file.
"""

import argparse
import os
import sys
import tempfile
from pathlib import Path

def check_dependencies():
    missing = []
    try:
        import matchering
    except ImportError:
        missing.append("matchering")
    try:
        import soundfile
    except ImportError:
        missing.append("soundfile")
    if missing:
        print(f"[ERROR] Missing packages: {', '.join(missing)}")
        print(f"  Install with: pip install {' '.join(missing)}")
        sys.exit(1)

def wav_to_ogg(wav_path: Path, ogg_path: Path):
    """Re-encode a WAV file to OGG Vorbis using soundfile."""
    import soundfile as sf
    data, samplerate = sf.read(str(wav_path))
    sf.write(str(ogg_path), data, samplerate, format="OGG", subtype="VORBIS")

def master_files(input_dir: Path, reference: Path, output_dir: Path, keep_wav: bool):
    import matchering as mg

    ogg_files = sorted(input_dir.glob("*.ogg"))
    if not ogg_files:
        print(f"[ERROR] No .ogg files found in: {input_dir}")
        sys.exit(1)

    output_dir.mkdir(parents=True, exist_ok=True)

    print(f"\n{'='*50}")
    print(f"  Input folder : {input_dir}")
    print(f"  Reference    : {reference}")
    print(f"  Output folder: {output_dir}")
    print(f"  Files found  : {len(ogg_files)}")
    print(f"  Keep WAV     : {keep_wav}")
    print(f"{'='*50}\n")

    success, failed = 0, []

    with tempfile.TemporaryDirectory() as tmp_dir:
        tmp_path = Path(tmp_dir)

        for i, ogg in enumerate(ogg_files, 1):
            out_ogg  = output_dir / ogg.name
            tmp_wav  = tmp_path / f"{ogg.stem}.wav"
            out_wav  = output_dir / f"{ogg.stem}.wav"

            print(f"[{i}/{len(ogg_files)}] {ogg.name}")
            print(f"         Mastering  ...", end=" ", flush=True)

            try:
                mg.process(
                    target=str(ogg),
                    reference=str(reference),
                    results=[mg.pcm16(str(tmp_wav))],
                )
                print("✓")

                print(f"         Encoding OGG ...", end=" ", flush=True)
                wav_to_ogg(tmp_wav, out_ogg)
                print("✓")

                if keep_wav:
                    import shutil
                    shutil.copy2(tmp_wav, out_wav)
                    print(f"         WAV saved  → {out_wav.name}")

                success += 1

            except Exception as e:
                print(f"✗  ({e})\n")
                failed.append((ogg.name, str(e)))

    print(f"\n{'='*50}")
    print(f"  Done! {success}/{len(ogg_files)} files mastered successfully.")
    if failed:
        print(f"\n  Failed files:")
        for name, reason in failed:
            print(f"    • {name}: {reason}")
    print(f"{'='*50}\n")


def main():
    parser = argparse.ArgumentParser(
        description="Batch master .ogg voicelines using Matchering"
    )
    parser.add_argument(
        "--input", "-i",
        required=True,
        help="Folder containing .ogg files to master"
    )
    parser.add_argument(
        "--reference", "-r",
        required=True,
        help="Reference audio file (.wav, .flac, or .ogg) to match loudness/tone to"
    )
    parser.add_argument(
        "--output", "-o",
        default=None,
        help="Output folder (default: <input_folder>/mastered)"
    )
    parser.add_argument(
        "--keep-wav",
        action="store_true",
        help="Also save the intermediate PCM WAV alongside each mastered OGG"
    )

    args = parser.parse_args()

    check_dependencies()

    input_dir  = Path(args.input).resolve()
    reference  = Path(args.reference).resolve()
    output_dir = Path(args.output).resolve() if args.output else input_dir / "mastered"

    if not input_dir.is_dir():
        print(f"[ERROR] Input folder not found: {input_dir}")
        sys.exit(1)
    if not reference.is_file():
        print(f"[ERROR] Reference file not found: {reference}")
        sys.exit(1)

    master_files(input_dir, reference, output_dir, args.keep_wav)


if __name__ == "__main__":
    main()