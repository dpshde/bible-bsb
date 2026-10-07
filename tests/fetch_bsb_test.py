"""Host checks for the BSB chapter pack layout."""

import importlib.util
import json
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


if __name__ == "__main__":
    unittest.main()
