#!/usr/bin/env python3
"""Build Flipper SD-card BSB chapter files from the hosted bsb.jsonl dataset.

Usage:
    python3 scripts/fetch_bsb.py --output bsb_sd/
    python3 scripts/fetch_bsb.py --input ../kindled/bsb.jsonl --output bsb_sd/

Output format per chapter:
    {"verses":[{"n":1,"t":"..."},{"n":2,"t":"..."}]}
"""

import argparse
import json
import shutil
import tempfile
import urllib.request
from pathlib import Path

BSB_JSONL_URL = "https://arweave.net/B6yeNb3lk_VkiIp-fTWVh13TlM94LjLK6kC63BPXa8s"

BOOK_CODES = {
    "Genesis": "GEN",
    "Exodus": "EXO",
    "Leviticus": "LEV",
    "Numbers": "NUM",
    "Deuteronomy": "DEU",
    "Joshua": "JOS",
    "Judges": "JDG",
    "Ruth": "RUT",
    "1 Samuel": "1SA",
    "2 Samuel": "2SA",
    "1 Kings": "1KI",
    "2 Kings": "2KI",
    "1 Chronicles": "1CH",
    "2 Chronicles": "2CH",
    "Ezra": "EZR",
    "Nehemiah": "NEH",
    "Esther": "EST",
    "Job": "JOB",
    "Psalm": "PSA",
    "Psalms": "PSA",
    "Proverbs": "PRO",
    "Ecclesiastes": "ECC",
    "Song of Solomon": "SNG",
    "Song Of Solomon": "SNG",
    "Isaiah": "ISA",
    "Jeremiah": "JER",
    "Lamentations": "LAM",
    "Ezekiel": "EZK",
    "Daniel": "DAN",
    "Hosea": "HOS",
    "Joel": "JOL",
    "Amos": "AMO",
    "Obadiah": "OBA",
    "Jonah": "JON",
    "Micah": "MIC",
    "Nahum": "NAM",
    "Habakkuk": "HAB",
    "Zephaniah": "ZEP",
    "Haggai": "HAG",
    "Zechariah": "ZEC",
    "Malachi": "MAL",
    "Matthew": "MAT",
    "Mark": "MRK",
    "Luke": "LUK",
    "John": "JHN",
    "Acts": "ACT",
    "Romans": "ROM",
    "1 Corinthians": "1CO",
    "2 Corinthians": "2CO",
    "Galatians": "GAL",
    "Ephesians": "EPH",
    "Philippians": "PHP",
    "Colossians": "COL",
    "1 Thessalonians": "1TH",
    "2 Thessalonians": "2TH",
    "1 Timothy": "1TI",
    "2 Timothy": "2TI",
    "Titus": "TIT",
    "Philemon": "PHM",
    "Hebrews": "HEB",
    "James": "JAS",
    "1 Peter": "1PE",
    "2 Peter": "2PE",
    "1 John": "1JN",
    "2 John": "2JN",
    "3 John": "3JN",
    "Jude": "JUD",
    "Revelation": "REV",
}


def download_jsonl(destination: Path) -> Path:
    req = urllib.request.Request(BSB_JSONL_URL, headers={"User-Agent": "Kindled-Spark/1.0"})
    with urllib.request.urlopen(req, timeout=60) as resp:
        with destination.open("wb") as out:
            shutil.copyfileobj(resp, out)
    return destination


def build_chapters(jsonl_path: Path, output_dir: Path) -> int:
    chapters = {}
    with jsonl_path.open("r", encoding="utf-8") as src:
        for line in src:
            if not line.strip():
                continue
            row = json.loads(line)
            code = BOOK_CODES[row["book"]].lower()
            chapter = int(row["chapter"])
            verse = {"n": int(row["verseNum"]), "t": row["text"]}
            chapters.setdefault((code, chapter), []).append(verse)

    if output_dir.exists():
        shutil.rmtree(output_dir)

    for (code, chapter), verses in chapters.items():
        verses.sort(key=lambda v: v["n"])
        book_dir = output_dir / code
        book_dir.mkdir(parents=True, exist_ok=True)
        out_path = book_dir / f"{chapter}.json"
        out_path.write_text(
            json.dumps({"verses": verses}, ensure_ascii=False, separators=(",", ":")),
            encoding="utf-8",
        )

    return len(chapters)


def main():
    parser = argparse.ArgumentParser(description="Build BSB chapter files for Kindled Spark")
    parser.add_argument("--input", type=Path, help="Existing bsb.jsonl path. Defaults to the hosted Arweave dataset.")
    parser.add_argument("--output", type=Path, default=Path("bsb_sd"), help="Output directory")
    args = parser.parse_args()

    if args.input:
        jsonl_path = args.input
        total = build_chapters(jsonl_path, args.output)
    else:
        with tempfile.TemporaryDirectory() as tmp:
            jsonl_path = download_jsonl(Path(tmp) / "bsb.jsonl")
            total = build_chapters(jsonl_path, args.output)

    print(f"Done. Wrote {total} chapter files to {args.output}")
    print(f"Copy the contents of {args.output} to /ext/apps_data/kindled_spark/bsb/ on your Flipper SD card.")


if __name__ == "__main__":
    main()
