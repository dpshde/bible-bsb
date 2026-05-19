#!/usr/bin/env python3
"""
Offline Resource Curation Pipeline for Bible [BSB] Garmin Connect IQ App.

Downloads chapters from the helloao API, strips metadata, and writes compact
JSON resource files to garmin_bible/resources/data/. Coverage:
  - New Testament (~260 chapters)
  - Psalms (150 chapters)
  - Proverbs (31 chapters)
  - Genesis 1-10

Resource files are declared in garmin_bible/resources/data/data.xml for
inclusion in the .prg by the Monkey C resource compiler.

Usage:
    python3 scripts/curate_garmin_data.py --output garmin_bible/resources/data/
"""

import argparse
import json
import os
import sys
import time
import urllib.request
import urllib.error

API_BASE = "https://bible.helloao.org/api/BSB"
REQUEST_TIMEOUT = 30
RETRY_ATTEMPTS = 3
SLEEP_BETWEEN_REQUESTS = 0.1  # seconds — be polite to the API

# Book coverage: (UPPERCASE OSIS code, book_index, start_chapter, end_chapter)
# The helloao API requires uppercase OSIS book IDs (e.g., GEN not gen).
COVERAGE = [
    # Genesis 1-10
    ("GEN", 0, 1, 10),
    # Psalms 1-150
    ("PSA", 18, 1, 150),
    # Proverbs 1-31
    ("PRO", 19, 1, 31),
    # New Testament
    ("MAT", 39, 1, 28),   # Matthew
    ("MRK", 40, 1, 16),   # Mark
    ("LUK", 41, 1, 24),   # Luke
    ("JHN", 42, 1, 21),   # John
    ("ACT", 43, 1, 28),   # Acts
    ("ROM", 44, 1, 16),   # Romans
    ("1CO", 45, 1, 16),   # 1 Corinthians
    ("2CO", 46, 1, 13),   # 2 Corinthians
    ("GAL", 47, 1, 6),    # Galatians
    ("EPH", 48, 1, 6),    # Ephesians
    ("PHP", 49, 1, 4),    # Philippians
    ("COL", 50, 1, 4),    # Colossians
    ("1TH", 51, 1, 5),    # 1 Thessalonians
    ("2TH", 52, 1, 3),    # 2 Thessalonians
    ("1TI", 53, 1, 6),    # 1 Timothy
    ("2TI", 54, 1, 4),    # 2 Timothy
    ("TIT", 55, 1, 3),    # Titus
    ("PHM", 56, 1, 1),    # Philemon
    ("HEB", 57, 1, 13),   # Hebrews
    ("JAS", 58, 1, 5),    # James
    ("1PE", 59, 1, 5),    # 1 Peter
    ("2PE", 60, 1, 3),    # 2 Peter
    ("1JN", 61, 1, 5),    # 1 John
    ("2JN", 62, 1, 1),    # 2 John
    ("3JN", 63, 1, 1),    # 3 John
    ("JUD", 64, 1, 1),    # Jude
    ("REV", 65, 1, 22),   # Revelation
]


def fetch_chapter(osis, chapter):
    """Fetch a single chapter from the helloao API with retries.

    helloao serves chapters via S3/CloudFront. The URL must use the
    *uppercase* OSIS code (e.g., GEN/1.json). A lowercase request
    returns an HTML 404 page instead of JSON.
    """
    url = f"{API_BASE}/{osis}/{chapter}.json"
    for attempt in range(1, RETRY_ATTEMPTS + 1):
        try:
            req = urllib.request.Request(
                url,
                headers={
                    "Accept": "application/json",
                    "User-Agent": "BibleBSB-Garmin-Curator/1.0",
                },
            )
            with urllib.request.urlopen(req, timeout=REQUEST_TIMEOUT) as resp:
                if resp.status != 200:
                    return None, f"HTTP {resp.status}"
                body = resp.read().decode("utf-8")
                # S3 may return an HTML 404 page with HTTP 200.
                # Detect by checking the first non-whitespace character.
                stripped = body.lstrip()
                if not stripped.startswith("{"):
                    return None, "Non-JSON response (likely 404 page)"
                data = json.loads(body)
                return data, None
        except urllib.error.HTTPError as e:
            if attempt == RETRY_ATTEMPTS:
                return None, f"HTTP {e.code}"
        except Exception as e:
            if attempt == RETRY_ATTEMPTS:
                return None, str(e)
        time.sleep(1.0 * attempt)
    return None, "Max retries exceeded"


def strip_metadata(data):
    """
    Strip metadata and produce compact JSON compatible with BibleJsonScanner.

    The scanner expects {"chapter": {"content": [...]}} at minimum,
    with verse objects having type, number, and content fields.

    We keep only verse objects (heading and line_break are skipped by
    the scanner; stripping them saves space). We strip footnote markers
    (noteId objects) from verse content. We strip poem/wordsOfJesus flags
    since the scanner only uses the text field from FormattedText objects.
    """
    chapter = data.get("chapter", {})
    raw_content = chapter.get("content", [])

    compact_content = []
    for item in raw_content:
        if not isinstance(item, dict):
            continue
        item_type = item.get("type")
        if item_type != "verse":
            continue

        verse_number = item.get("number")
        raw_verse_content = item.get("content", [])

        compact_verse_content = []
        for vc in raw_verse_content:
            if isinstance(vc, str):
                compact_verse_content.append(vc)
            elif isinstance(vc, dict):
                # Keep only text from FormattedText objects;
                # drop noteId, wordsOfJesus, poem, heading, lineBreak objects.
                text = vc.get("text")
                if isinstance(text, str):
                    compact_verse_content.append({"text": text})
                # noteId and other markers are dropped entirely

        compact_content.append({
            "type": "verse",
            "number": verse_number,
            "content": compact_verse_content,
        })

    return {"chapter": {"content": compact_content}}


def write_resource_file(data, out_dir, osis, chapter):
    """Write a compact JSON resource file.

    The resource id / filename use lowercase OSIS codes (e.g., gen_1.json)
    to match the Monkey C resource naming used by the app at runtime.
    """
    osis_lower = osis.lower()
    filename = f"{osis_lower}_{chapter}.json"
    filepath = os.path.join(out_dir, filename)
    with open(filepath, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, separators=(",", ":"))
    return filepath


def _safe_xml_id(filename):
    """Return a valid Monkey C identifier from a JSON filename.

    Monkey C identifiers must start with a letter.  If the OSIS prefix
    begins with a digit (e.g. 1co, 2co) the digit is moved to the end
    so the identifier starts with a letter (co1, co2).
    """
    base = filename.replace(".json", "").replace("-", "_")
    if base[0].isdigit():
        parts = base.split("_", 1)
        if len(parts) == 2:
            return parts[0][1:] + parts[0][0] + "_" + parts[1]
        return base[1:] + base[0]
    return base


def generate_data_xml(out_dir, written_files):
    """Generate the resources/data/data.xml declaration file."""
    xml_path = os.path.join(out_dir, "data.xml")
    lines = [
        '<?xml version="1.0" encoding="UTF-8"?>',
        '<resources xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"',
        '    xsi:noNamespaceSchemaLocation="http://developer.garmin.com/downloads/connect-iq/resources.xsd">',
    ]
    for filepath in sorted(written_files):
        filename = os.path.basename(filepath)
        resource_id = _safe_xml_id(filename)
        lines.append(f'    <jsonData id="{resource_id}" filename="{filename}"/>')
    lines.append("</resources>")

    with open(xml_path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    return xml_path


def _collect_written_files(out_dir, coverage):
    """Collect already-written resource file paths from a previous run."""
    files = []
    for osis, book_index, start_ch, end_ch in coverage:
        osis_lower = osis.lower()
        for ch in range(start_ch, end_ch + 1):
            filepath = os.path.join(out_dir, f"{osis_lower}_{ch}.json")
            if os.path.exists(filepath):
                files.append(filepath)
    return files


def _safe_const_name(osis):
    """Return a Monkey-C-valid constant name for the given OSIS code."""
    if osis[0].isdigit():
        return osis[1:] + osis[0]
    return osis


def generate_bible_resources_mc(source_dir, coverage, written_files):
    """Generate garmin_bible/source/BibleResources.mc lookup module."""
    # Map book_index -> list of (chapter, resource_id)
    book_resources = {}
    for osis, book_index, start_ch, end_ch in coverage:
        osis_lower = osis.lower()
        entries = []
        for ch in range(start_ch, end_ch + 1):
            resource_id = _safe_xml_id(f"{osis_lower}_{ch}.json")
            entries.append((ch, resource_id))
        book_resources[book_index] = entries

    lines = [
        "using Toybox.Application;",
        "import Toybox.Lang;",
        "",
        "// Auto-generated by scripts/curate_garmin_data.py — do not edit manually.",
        "module BibleResources {",
        "",
        "    // Offline coverage: New Testament + Psalms + Proverbs + Genesis 1-10",
        "    // Total chapters: " + str(sum(end - start + 1 for _, _, start, end in coverage)),
        "",
    ]

    # Per-book constant arrays of ResourceId
    for book_index in sorted(book_resources.keys()):
        entries = book_resources[book_index]
        osis_code = entries[0][1].split("_")[0].upper()
        const_name = _safe_const_name(osis_code)
        lines.append(f"    const {const_name}_RESOURCES = [")
        for ch, resource_id in entries:
            lines.append(f"        Rez.JsonData.{resource_id},")
        lines.append("    ] as Array<ResourceId>;")
        lines.append("")

    # Helper: getResourceId
    lines.append("    function getResourceId(bookIndex as Number, chapter as Number) as ResourceId? {")
    first = True
    for book_index in sorted(book_resources.keys()):
        entries = book_resources[book_index]
        osis_code = entries[0][1].split("_")[0].upper()
        const_name = _safe_const_name(osis_code)
        max_ch = entries[-1][0]
        prefix = "        if" if first else "        } else if"
        first = False
        lines.append(f"        {prefix} (bookIndex == {book_index}) {{")
        lines.append(f"            if (chapter >= 1 && chapter <= {max_ch}) {{")
        lines.append(f"                return {const_name}_RESOURCES[chapter - 1];")
        lines.append("            }")
    lines.append("        }")
    lines.append("        return null;")
    lines.append("    }")
    lines.append("")

    # Helper: hasResource
    lines.append("    function hasResource(bookIndex as Number, chapter as Number) as Boolean {")
    lines.append("        return getResourceId(bookIndex, chapter) != null;")
    lines.append("    }")
    lines.append("")

    # Helper: totalResourceCount
    lines.append("    function getTotalResourceCount() as Number {")
    total = sum(end - start + 1 for _, _, start, end in coverage)
    lines.append(f"        return {total};")
    lines.append("    }")
    lines.append("")

    lines.append("}")

    mc_path = os.path.join(source_dir, "BibleResources.mc")
    with open(mc_path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    return mc_path


def main():
    parser = argparse.ArgumentParser(description="Curate offline Bible chapter resources")
    parser.add_argument(
        "--output",
        default="garmin_bible/resources/data",
        help="Output directory for JSON resource files",
    )
    parser.add_argument(
        "--resume",
        action="store_true",
        help="Skip chapters that already have resource files",
    )
    args = parser.parse_args()

    out_dir = args.output
    os.makedirs(out_dir, exist_ok=True)

    total_chapters = sum(end - start + 1 for _, _, start, end in COVERAGE)
    written_files = []
    skipped = 0
    failed = 0
    downloaded = 0
    total_raw_size = 0
    total_compact_size = 0

    print(f"Curating {total_chapters} chapters to {out_dir} ...")
    print(f"Resume mode: {args.resume}")

    processed = 0
    for osis, book_index, start_ch, end_ch in COVERAGE:
        for chapter in range(start_ch, end_ch + 1):
            processed += 1
            filename = f"{osis}_{chapter}.json"
            filepath = os.path.join(out_dir, filename)

            if args.resume and os.path.exists(filepath):
                written_files.append(filepath)
                skipped += 1
                if processed % 50 == 0:
                    print(f"  [{processed}/{total_chapters}] {osis} {chapter} — skipped (exists)")
                continue

            data, err = fetch_chapter(osis, chapter)
            if err:
                print(f"  [{processed}/{total_chapters}] FAILED {osis} {chapter}: {err}")
                failed += 1
                continue

            compact = strip_metadata(data)
            filepath = write_resource_file(compact, out_dir, osis, chapter)
            written_files.append(filepath)
            downloaded += 1

            # Track sizes
            raw_size = len(json.dumps(data, ensure_ascii=False))
            compact_size = len(json.dumps(compact, ensure_ascii=False, separators=(",", ":")))
            total_raw_size += raw_size
            total_compact_size += compact_size

            if processed % 10 == 0 or processed == total_chapters:
                print(f"  [{processed}/{total_chapters}] {osis} {chapter} — ok (compact {compact_size}B)")

            time.sleep(SLEEP_BETWEEN_REQUESTS)

    # Generate XML declarations
    xml_path = generate_data_xml(out_dir, written_files)

    # Generate Monkey C lookup module
    source_dir = os.path.join(os.path.dirname(os.path.dirname(out_dir)), "source")
    os.makedirs(source_dir, exist_ok=True)
    mc_path = generate_bible_resources_mc(source_dir, COVERAGE, written_files)

    # Summary
    print("")
    print("=" * 50)
    print("Curation complete!")
    print(f"  Total chapters:     {total_chapters}")
    print(f"  Downloaded:         {downloaded}")
    print(f"  Skipped (resume):   {skipped}")
    print(f"  Failed:             {failed}")
    print(f"  Raw JSON total:     {total_raw_size:,} bytes")
    print(f"  Compact JSON total: {total_compact_size:,} bytes")
    print(f"  Compression ratio:  {total_compact_size / max(total_raw_size, 1):.1%}")
    print(f"  XML declarations:   {xml_path}")
    print("=" * 50)

    if failed > 0:
        sys.exit(1)


if __name__ == "__main__":
    main()
