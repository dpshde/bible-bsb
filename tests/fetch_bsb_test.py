"""Host checks for the BSB chapter pack layout."""

import importlib.util
import json
import struct
import subprocess
import tempfile
import unittest
import zipfile
from pathlib import Path


def load_fetch_bsb():
    path = Path(__file__).resolve().parents[1] / "scripts" / "fetch_bsb.py"
    spec = importlib.util.spec_from_file_location("fetch_bsb", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class FetchBsbTest(unittest.TestCase):
    def test_release_zip_uses_bible_bsb_layout(self):
        fetch_bsb = load_fetch_bsb()
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            jsonl = root / "bsb.jsonl"
            jsonl.write_text(
                "\n".join(
                    [
                        json.dumps(
                            {
                                "book": "Genesis",
                                "chapter": 1,
                                "verseNum": 1,
                                "text": "In the beginning God created the heavens and the earth.",
                            }
                        ),
                        json.dumps(
                            {
                                "book": "John",
                                "chapter": 3,
                                "verseNum": 16,
                                "text": "For God so loved the world",
                            }
                        ),
                    ]
                )
                + "\n",
                encoding="utf-8",
            )
            chapter_dir = root / "chapters"
            total = fetch_bsb.build_chapters(jsonl, chapter_dir)
            self.assertEqual(total, 2)
            self.assertTrue((chapter_dir / "gen" / "1.json").is_file())
            self.assertTrue((chapter_dir / "jhn" / "3.json").is_file())

            zip_path = root / "bsb-data-v1.zip"
            zipped = fetch_bsb.write_release_zip(chapter_dir, zip_path)
            self.assertEqual(zipped, 2)
            with zipfile.ZipFile(zip_path) as archive:
                names = set(archive.namelist())
            self.assertEqual(names, {"bsb/gen/1.json", "bsb/jhn/3.json"})

    def test_pack_roundtrip_and_c_finder(self):
        fetch_bsb = load_fetch_bsb()
        heatshrink2 = importlib.import_module("heatshrink2")
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            jsonl = root / "bsb.jsonl"
            genesis = "In the beginning God created the heavens and the earth."
            john = "For God so loved the world"
            jsonl.write_text(
                "\n".join(
                    [
                        json.dumps(
                            {
                                "book": "John",
                                "chapter": 3,
                                "verseNum": 16,
                                "text": john,
                            }
                        ),
                        json.dumps(
                            {
                                "book": "Genesis",
                                "chapter": 1,
                                "verseNum": 1,
                                "text": genesis,
                            }
                        ),
                    ]
                )
                + "\n",
                encoding="utf-8",
            )
            chapter_dir = root / "chapters"
            fetch_bsb.build_chapters(jsonl, chapter_dir)
            pack_path = root / "bsb.pack"
            packed = fetch_bsb.pack_chapters(chapter_dir, pack_path, require_canon=False)
            self.assertEqual(packed, 2)

            blob = pack_path.read_bytes()
            magic, count, record_size, window, lookahead, _reserved = struct.unpack_from(
                "<4sHHBBH", blob
            )
            self.assertEqual(magic, b"BSB1")
            self.assertEqual(count, 2)
            self.assertEqual(record_size, fetch_bsb.PACK_RECORD_SIZE)
            self.assertEqual(window, fetch_bsb.PACK_HS_WINDOW)
            self.assertEqual(lookahead, fetch_bsb.PACK_HS_LOOKAHEAD)

            records = []
            for index in range(count):
                start = fetch_bsb.PACK_HEADER_SIZE + index * record_size
                book, chapter, comp_size, raw_size, data_offset = struct.unpack_from(
                    "<BBHHI", blob, start
                )
                records.append((book, chapter, comp_size, raw_size, data_offset))
            self.assertEqual([record[0:2] for record in records], [(0, 1), (42, 3)])

            for book, chapter, comp_size, raw_size, data_offset in records:
                decoded = heatshrink2.decompress(
                    blob[data_offset : data_offset + comp_size],
                    window_sz2=window,
                    lookahead_sz2=lookahead,
                )
                self.assertEqual(len(decoded), raw_size)
                payload = json.loads(decoded)
                if book == 0:
                    self.assertEqual(payload["verses"][0]["t"], genesis)
                else:
                    self.assertEqual(payload["verses"][0]["t"], john)

            binary = root / "bible-pack-test"
            repo = Path(__file__).resolve().parents[1]
            subprocess.run(
                [
                    "gcc",
                    "-Wall",
                    "-Wextra",
                    "-Werror",
                    "-I",
                    str(repo / "bible_bsb"),
                    "-o",
                    str(binary),
                    str(repo / "tests" / "bible-pack" / "bible-pack-test.c"),
                    str(repo / "bible_bsb" / "bible_pack.c"),
                ],
                check=True,
            )
            subprocess.run([str(binary)], check=True)

    def test_shipped_pack_covers_the_canon(self):
        fetch_bsb = load_fetch_bsb()
        heatshrink2 = importlib.import_module("heatshrink2")
        pack_path = Path(__file__).resolve().parents[1] / "bible_bsb" / "assets" / "bsb.pack"
        blob = pack_path.read_bytes()
        magic, count, record_size, window, lookahead, _reserved = struct.unpack_from(
            "<4sHHBBH", blob
        )
        self.assertEqual(magic, b"BSB1")
        self.assertEqual(count, sum(fetch_bsb.PACK_CHAPTER_COUNTS))
        self.assertEqual(count, 1189)
        self.assertEqual(record_size, fetch_bsb.PACK_RECORD_SIZE)
        self.assertEqual(
            (window, lookahead), (fetch_bsb.PACK_HS_WINDOW, fetch_bsb.PACK_HS_LOOKAHEAD)
        )

        directory_end = fetch_bsb.PACK_HEADER_SIZE + count * record_size
        previous = (-1, -1)
        cursor = directory_end
        samples = {}
        for index in range(count):
            start = fetch_bsb.PACK_HEADER_SIZE + index * record_size
            book, chapter, comp_size, raw_size, data_offset = struct.unpack_from(
                "<BBHHI", blob, start
            )
            self.assertGreater(comp_size, 0)
            self.assertGreater(raw_size, 0)
            self.assertLessEqual(raw_size, 20000)
            self.assertEqual(data_offset, cursor)
            self.assertLessEqual(data_offset + comp_size, len(blob))
            self.assertLess(previous, (book, chapter))
            previous = (book, chapter)
            cursor += comp_size
            if (book, chapter) in {(0, 1), (18, 119), (42, 3), (65, 22)}:
                samples[(book, chapter)] = blob[data_offset : data_offset + comp_size]
        self.assertEqual(cursor, len(blob))
        self.assertEqual(len(samples), 4)

        psalm = json.loads(
            heatshrink2.decompress(samples[(18, 119)], window_sz2=window, lookahead_sz2=lookahead)
        )
        self.assertEqual(len(psalm["verses"]), 176)
        john = json.loads(
            heatshrink2.decompress(samples[(42, 3)], window_sz2=window, lookahead_sz2=lookahead)
        )
        self.assertIn("loved", john["verses"][15]["t"])
        genesis = json.loads(
            heatshrink2.decompress(samples[(0, 1)], window_sz2=window, lookahead_sz2=lookahead)
        )
        self.assertTrue(genesis["verses"][0]["t"].startswith("In the beginning"))


if __name__ == "__main__":
    unittest.main()
