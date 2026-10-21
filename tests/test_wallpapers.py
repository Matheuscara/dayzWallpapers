import importlib.util
import json
from pathlib import Path
import random
import subprocess
import sys
import tempfile
import unittest

HELPER = Path(__file__).parents[1] / "plugin/wallpapers.py"
spec = importlib.util.spec_from_file_location("wallpapers", HELPER)
wallpapers = importlib.util.module_from_spec(spec)
spec.loader.exec_module(wallpapers)


class WallpaperCollectionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / "collection"
        self.root.mkdir()

    def image(self, name):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(b"local test fixture")
        return path

    def test_categories_follow_folders_and_nested_paths(self):
        self.image("City/a.JPG")
        self.image("City/Night/b.png")
        self.image("loose.webp")
        self.image("notes.txt")
        self.image(".hidden.png")
        result = wallpapers.scan(self.root)
        self.assertEqual({c["id"] for c in result["categories"]}, {"City", "City/Night", "."})
        self.assertEqual(len(result["images"]), 3)

    def test_symlink_gallery_is_deduplicated_and_outside_files_are_ignored(self):
        image = self.image("City/a.png")
        gallery = self.root / "00-Gallery"
        gallery.mkdir()
        (gallery / "a.png").symlink_to(image)
        outside = self.root.parent / "private.png"
        outside.write_bytes(b"outside")
        (gallery / "outside.png").symlink_to(outside)
        (gallery / "loop").symlink_to(self.root, target_is_directory=True)
        result = wallpapers.scan(self.root, {"00-Gallery"})
        self.assertEqual(len(result["images"]), 1)
        self.assertEqual(result["images"][0]["category"], "City")
        self.assertEqual(len(wallpapers.scan(self.root)["images"]), 1)
        self.assertEqual(wallpapers.scan(self.root)["images"][0]["category"], "City")
        private = self.image("Ignored/private.png")
        (gallery / "private.png").symlink_to(private)
        self.assertEqual(len(wallpapers.scan(self.root, {"Ignored"})["images"]), 1)

    def test_random_stays_in_category_and_avoids_immediate_repeat(self):
        first = self.image("City/a.png")
        second = self.image("City/b.png")
        self.image("Forest/c.png")
        images = wallpapers.scan(self.root)["images"]
        self.assertEqual(wallpapers.choose(images, "City", current=str(first), rng=random.Random(1)), str(second))
        self.assertEqual(wallpapers.choose(images, "Missing"), "")

    def test_sequence_wraps_and_deleted_files_disappear(self):
        first = self.image("City/a.png")
        last = self.image("City/b.png")
        images = wallpapers.scan(self.root)["images"]
        self.assertEqual(wallpapers.choose(images, "City", "sequential", str(last)), str(first))
        last.unlink()
        self.assertEqual(len(wallpapers.scan(self.root)["images"]), 1)

    def test_filename_is_data_and_url_is_encoded(self):
        path = self.image("Room/a #1 $(touch marker).png")
        result = wallpapers.scan(self.root)
        self.assertEqual(result["images"][0]["path"], str(path))
        self.assertIn("%23", result["images"][0]["url"])
        self.assertFalse((self.root / "marker").exists())

    def test_scan_is_bounded_and_missing_directory_reports_json(self):
        self.image("a.png")
        self.image("b.png")
        result = wallpapers.scan(self.root, limit=1)
        self.assertEqual(len(result["images"]), 1)
        self.assertEqual(len(result["warnings"]), 1)
        output = subprocess.check_output([sys.executable, str(HELPER), "--root", str(self.root / "missing")], text=True)
        self.assertTrue(json.loads(output)["error"])

    def test_manual_selection_is_checked_against_current_index(self):
        path = self.image("a.png")
        argv = [sys.executable, str(HELPER), "--root", str(self.root), "--select", str(path)]
        self.assertEqual(json.loads(subprocess.check_output(argv, text=True))["choice"], str(path))
        path.unlink()
        self.assertEqual(json.loads(subprocess.check_output(argv, text=True))["choice"], "")
