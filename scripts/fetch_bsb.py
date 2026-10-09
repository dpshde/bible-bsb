#!/usr/bin/env python3
"""Build the bundled BSB chapter pack from the hosted bsb.jsonl dataset.

Usage:
    python3 scripts/fetch_bsb.py --output bsb_sd/
    python3 scripts/fetch_bsb.py --input ../kindled/bsb.jsonl --output bsb_sd/

Output format per chapter:
    {"verses":[{"n":1,"t":"..."},{"n":2,"t":"..."}]}
"""

import argparse
import json
import shutil
import struct
import tempfile
import urllib.request
import zipfile
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

# Same order as bible_bsb/bible_books.c OSIS_BOOK_CODES. Index is the pack key.
PACK_BOOK_CODES = (
    "GEN", "EXO", "LEV", "NUM", "DEU", "JOS", "JDG", "RUT", "1SA", "2SA", "1KI",
    "2KI", "1CH", "2CH", "EZR", "NEH", "EST", "JOB", "PSA", "PRO", "ECC", "SNG",
    "ISA", "JER", "LAM", "EZK", "DAN", "HOS", "JOL", "AMO", "OBA", "JON", "MIC",
    "NAM", "HAB", "ZEP", "HAG", "ZEC", "MAL", "MAT", "MRK", "LUK", "JHN", "ACT",
    "ROM", "1CO", "2CO", "GAL", "EPH", "PHP", "COL", "1TH", "2TH", "1TI", "2TI",
    "TIT", "PHM", "HEB", "JAS", "1PE", "2PE", "1JN", "2JN", "3JN", "JUD", "REV",
)

# Chapter counts, same order as PACK_BOOK_CODES / BOOK_CHAPTER_COUNTS.
PACK_CHAPTER_COUNTS = (
    50, 40, 27, 36, 34, 24, 21, 4, 31, 24, 22, 25, 29, 36, 10, 13, 10, 42, 150, 31, 12, 8,
    66, 52, 5, 48, 12, 14, 3, 9, 1, 4, 7, 3, 3, 3, 2, 14, 4, 28, 16, 24, 21, 28,
    16, 16, 13, 6, 6, 4, 4, 5, 3, 6, 4, 3, 1, 13, 5, 5, 3, 5, 1, 1, 1, 22,
)

# Must match bible_bsb/bible_pack.h. Window 11 / lookahead 4 is the size/RAM tradeoff.
PACK_MAGIC = b"BSB1"
PACK_RECORD_SIZE = 10
PACK_HEADER_SIZE = 12
PACK_HS_WINDOW = 11
PACK_HS_LOOKAHEAD = 4


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


def pack_chapters(chapter_dir: Path, pack_path: Path, require_canon: bool = True) -> int:
    """Write the heatshrink chapter pack the app bundles as assets/bsb.pack.

    Each chapter is an independent heatshrink stream so the Flipper can decode
    one chapter without holding the rest of the Bible in RAM.
    """
    import heatshrink2

    if len(PACK_BOOK_CODES) != 66 or len(PACK_CHAPTER_COUNTS) != 66:
        raise RuntimeError("pack book table must cover the 66-book canon")

    code_to_index = {code.lower(): index for index, code in enumerate(PACK_BOOK_CODES)}
    expected = {
        (index, chapter)
        for index, count in enumerate(PACK_CHAPTER_COUNTS)
        for chapter in range(1, count + 1)
    }
    found = {}
    for path in sorted(chapter_dir.rglob("*.json")):
        code = path.parent.name.lower()
        if code not in code_to_index:
            raise ValueError(f"unknown book directory {path.parent.name}")
        book = code_to_index[code]
        chapter = int(path.stem)
        key = (book, chapter)
        if key in found:
            raise ValueError(f"duplicate chapter {path}")
        raw = path.read_bytes()
        if len(raw) > 65535:
            raise ValueError(f"{path} is larger than a pack record can describe")
        compressed = heatshrink2.compress(
            raw, window_sz2=PACK_HS_WINDOW, lookahead_sz2=PACK_HS_LOOKAHEAD
        )
        if len(compressed) > 65535:
            raise ValueError(f"{path} did not compress under the record size limit")
        found[key] = (compressed, len(raw))

    if require_canon:
        missing = expected - found.keys()
        extra = found.keys() - expected
        if missing or extra:
            raise ValueError(f"chapter set mismatch: missing {len(missing)} extra {len(extra)}")

    ordered = sorted(found)
    directory_end = PACK_HEADER_SIZE + len(ordered) * PACK_RECORD_SIZE
    offset = directory_end
    records = []
    payloads = []
    for book, chapter in ordered:
        compressed, raw_size = found[(book, chapter)]
        records.append(struct.pack("<BBHHI", book, chapter, len(compressed), raw_size, offset))
        payloads.append(compressed)
        offset += len(compressed)

    header = struct.pack(
        "<4sHHBBH",
        PACK_MAGIC,
        len(ordered),
        PACK_RECORD_SIZE,
        PACK_HS_WINDOW,
        PACK_HS_LOOKAHEAD,
        0,
    )
    pack_path.parent.mkdir(parents=True, exist_ok=True)
    pack_path.write_bytes(header + b"".join(records) + b"".join(payloads))
    return len(ordered)


def write_release_zip(chapter_dir: Path, zip_path: Path) -> int:
    """Pack chapter files as bsb/<book>/<chapter>.json."""
    zip_path.parent.mkdir(parents=True, exist_ok=True)
    count = 0
    with zipfile.ZipFile(zip_path, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        for path in sorted(chapter_dir.rglob("*.json")):
            rel = path.relative_to(chapter_dir).as_posix()
            archive.write(path, f"bsb/{rel}")
            count += 1
    return count


def main():
    parser = argparse.ArgumentParser(description="Build BSB chapter files for Bible [BSB]")
    parser.add_argument("--input", type=Path, help="Existing bsb.jsonl path. Defaults to the hosted Arweave dataset.")
    parser.add_argument("--output", type=Path, default=Path("bsb_sd"), help="Output directory")
    parser.add_argument(
        "--pack-dir",
        type=Path,
        help="Pack this existing chapter directory instead of building one",
    )
    parser.add_argument(
        "--pack",
        type=Path,
        help="Write the bundled heatshrink pack (bible_bsb/assets/bsb.pack)",
    )
    parser.add_argument(
        "--zip",
        type=Path,
        help="Also write a zip of bsb/<book>/<chapter>.json",
    )
    args = parser.parse_args()

    chapter_dir = args.pack_dir
    total = None
    if chapter_dir is None:
        if args.input:
            jsonl_path = args.input
            total = build_chapters(jsonl_path, args.output)
        else:
            with tempfile.TemporaryDirectory() as tmp:
                jsonl_path = download_jsonl(Path(tmp) / "bsb.jsonl")
                total = build_chapters(jsonl_path, args.output)
        chapter_dir = args.output
        print(f"Done. Wrote {total} chapter files to {args.output}")

    if args.pack:
        packed = pack_chapters(chapter_dir, args.pack)
        print(f"Wrote {packed} chapters to {args.pack}")
    if args.zip:
        zipped = write_release_zip(chapter_dir, args.zip)
        print(f"Wrote {zipped} chapter files to {args.zip}")


if __name__ == "__main__":
    main()
