"""
KCD2 Mercenaries Mod - Auto Translator
Reads English_xml.xml as the source of truth, finds strings missing or
untranslated in each target language file, translates them via DeepL,
and writes the results back.

Usage:
    python translate.py [--api-key KEY] [--loc-dir PATH] [--dry-run]

API key priority: --api-key flag > DEEPL_API_KEY env var > .env file in script dir
"""

import argparse
import os
import sys
import time
import xml.etree.ElementTree as ET
from pathlib import Path
from copy import deepcopy

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

LANGUAGE_MAP = {
    # filename stem -> DeepL target language code
    "Chineses_xml": "ZH",       # Simplified Chinese
    "Czech_xml":    "CS",
    "French_xml":   "FR",
    "German_xml":   "DE",
    "Russian_xml":  "RU",
    "Turkish_xml":  "TR",
}

SOURCE_FILE = "English_xml.xml"
DEEPL_SOURCE_LANG = "EN"

# How many strings to batch per DeepL request (API limit is 50 per call)
BATCH_SIZE = 40

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def load_api_key(cli_key: str | None) -> str:
    """Resolve API key from CLI arg, env var, or .env file."""
    if cli_key:
        return cli_key

    key = os.environ.get("DEEPL_API_KEY")
    if key:
        return key

    env_file = Path(__file__).parent / ".env"
    if env_file.exists():
        for line in env_file.read_text().splitlines():
            line = line.strip()
            if line.startswith("DEEPL_API_KEY="):
                key = line.split("=", 1)[1].strip().strip('"').strip("'")
                if key:
                    return key

    print("ERROR: DeepL API key not found.")
    print("  Set DEEPL_API_KEY env var, pass --api-key, or create a .env file with:")
    print("  DEEPL_API_KEY=your_key_here")
    sys.exit(1)


def parse_xml(path: Path) -> tuple[ET.ElementTree, list[ET.Element]]:
    """Parse a localization XML and return (tree, list_of_row_elements)."""
    tree = ET.parse(path)
    root = tree.getroot()
    rows = root.findall("Row")
    return tree, rows


def rows_to_dict(rows: list[ET.Element]) -> dict[str, ET.Element]:
    """Map string ID (Cell[0]) -> Row element."""
    result = {}
    for row in rows:
        cells = row.findall("Cell")
        if cells:
            key = (cells[0].text or "").strip()
            if key:
                result[key] = row
    return result


def make_row(string_id: str, value: str) -> ET.Element:
    """Create a new <Row> element."""
    row = ET.Element("Row")
    c0 = ET.SubElement(row, "Cell")
    c0.text = string_id
    c1 = ET.SubElement(row, "Cell")
    c1.text = value
    c2 = ET.SubElement(row, "Cell")
    c2.text = value  # fallback = same as value
    return row


def write_xml(tree: ET.ElementTree, path: Path):
    """Write XML back, preserving a simple header."""
    ET.indent(tree.getroot(), space="\t")
    tree.write(path, encoding="utf-8", xml_declaration=True)


def translate_batch(texts: list[str], target_lang: str, api_key: str) -> list[str]:
    """Send a batch to DeepL and return translated strings."""
    import urllib.request
    import urllib.parse
    import json

    # Use free API endpoint if key ends with :fx, otherwise paid
    base = "https://api-free.deepl.com" if api_key.endswith(":fx") else "https://api.deepl.com"
    url = f"{base}/v2/translate"

    payload = {
        "auth_key": api_key,
        "text": texts,
        "source_lang": DEEPL_SOURCE_LANG,
        "target_lang": target_lang,
        "tag_handling": "xml",          # preserve any inline XML tags in strings
        "ignore_tags": "Cell,Row,Table",
    }

    data = urllib.parse.urlencode(payload, doseq=True).encode()
    req = urllib.request.Request(url, data=data, method="POST")
    req.add_header("Content-Type", "application/x-www-form-urlencoded")

    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            result = json.loads(resp.read())
            return [t["text"] for t in result["translations"]]
    except urllib.error.HTTPError as e:
        body = e.read().decode()
        print(f"  DeepL HTTP error {e.code}: {body}")
        raise
    except Exception as e:
        print(f"  DeepL request failed: {e}")
        raise


# ---------------------------------------------------------------------------
# Main logic
# ---------------------------------------------------------------------------

def process_language(
    lang_stem: str,
    deepl_code: str,
    loc_dir: Path,
    english_dict: dict[str, ET.Element],
    api_key: str,
    dry_run: bool,
):
    target_file = loc_dir / f"{lang_stem}.xml"

    # Load or create target file
    if target_file.exists():
        tree, existing_rows = parse_xml(target_file)
        target_dict = rows_to_dict(existing_rows)
        root = tree.getroot()
    else:
        print(f"  {lang_stem}: file not found, will create from scratch.")
        root = ET.Element("Table")
        tree = ET.ElementTree(root)
        target_dict = {}

    # Find strings that need translation:
    # - missing entirely from target
    # - present but Cell[1] text is identical to English (copy-paste placeholder)
    to_translate: list[tuple[str, str]] = []  # (string_id, english_text)

    for string_id, en_row in english_dict.items():
        en_cells = en_row.findall("Cell")
        en_text = (en_cells[1].text or "").strip() if len(en_cells) > 1 else ""

        if string_id not in target_dict:
            to_translate.append((string_id, en_text))
        else:
            tgt_cells = target_dict[string_id].findall("Cell")
            tgt_text = (tgt_cells[1].text or "").strip() if len(tgt_cells) > 1 else ""
            if tgt_text == en_text:
                # Still English — needs translation
                to_translate.append((string_id, en_text))

    if not to_translate:
        print(f"  {lang_stem}: up to date, nothing to translate.")
        return

    print(f"  {lang_stem} [{deepl_code}]: {len(to_translate)} string(s) to translate...")

    if dry_run:
        for sid, txt in to_translate:
            print(f"    [DRY RUN] Would translate: {sid!r} -> {txt[:60]!r}")
        return

    # Translate in batches
    translated: dict[str, str] = {}
    ids_batch, texts_batch = [], []

    def flush_batch():
        if not texts_batch:
            return
        results = translate_batch(texts_batch, deepl_code, api_key)
        for sid, result in zip(ids_batch, results):
            translated[sid] = result
        ids_batch.clear()
        texts_batch.clear()

    for string_id, en_text in to_translate:
        ids_batch.append(string_id)
        texts_batch.append(en_text)
        if len(texts_batch) >= BATCH_SIZE:
            flush_batch()
            time.sleep(0.2)  # be polite to the API

    flush_batch()

    # Apply translations: update existing rows or append new ones
    for string_id, translation in translated.items():
        if string_id in target_dict:
            tgt_row = target_dict[string_id]
            cells = tgt_row.findall("Cell")
            if len(cells) > 1:
                cells[1].text = translation
            if len(cells) > 2:
                cells[2].text = translation
        else:
            new_row = make_row(string_id, translation)
            root.append(new_row)

    write_xml(tree, target_file)
    print(f"  {lang_stem}: wrote {len(translated)} translation(s) -> {target_file.name}")


def main():
    parser = argparse.ArgumentParser(description="KCD2 Mod Auto Translator (DeepL)")
    parser.add_argument("--api-key", help="DeepL API key")
    parser.add_argument(
        "--loc-dir",
        default=str(Path(__file__).parent / "localization"),
        help="Path to the localization folder (default: ./localization)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Show what would be translated without calling DeepL or writing files",
    )
    parser.add_argument(
        "--langs",
        nargs="+",
        help="Only translate specific language stems, e.g. --langs German_xml French_xml",
    )
    args = parser.parse_args()

    loc_dir = Path(args.loc_dir)
    if not loc_dir.exists():
        print(f"ERROR: Localization directory not found: {loc_dir}")
        sys.exit(1)

    english_file = loc_dir / SOURCE_FILE
    if not english_file.exists():
        print(f"ERROR: Source file not found: {english_file}")
        sys.exit(1)

    api_key = load_api_key(args.api_key) if not args.dry_run else "dry-run"

    print(f"Source: {english_file}")
    _, english_rows = parse_xml(english_file)
    english_dict = rows_to_dict(english_rows)
    print(f"Loaded {len(english_dict)} English string(s).\n")

    langs = LANGUAGE_MAP
    if args.langs:
        langs = {k: v for k, v in LANGUAGE_MAP.items() if k in args.langs}
        unknown = set(args.langs) - set(LANGUAGE_MAP)
        if unknown:
            print(f"WARNING: Unknown language stems: {unknown}")

    for lang_stem, deepl_code in langs.items():
        process_language(lang_stem, deepl_code, loc_dir, english_dict, api_key, args.dry_run)

    print("\nDone.")


if __name__ == "__main__":
    main()