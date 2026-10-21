import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("installer", Path(__file__).parents[1] / "scripts/install.py")
installer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(installer)
SOURCE = Path(__file__).parents[1] / "plugin"


class InstallerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.config = Path(self.temp.name) / "config"
        self.state = Path(self.temp.name) / "state"

    def install(self, **kwargs):
        return installer.install(SOURCE, self.config, self.state, **kwargs)

    def test_dry_run_has_no_writes(self):
        self.install(dry_run=True)
        self.assertFalse(self.config.exists())
        self.assertFalse(self.state.exists())

    def test_idempotent_install(self):
        target = self.install()
        before = target.lstat().st_ino
        self.install()
        self.assertEqual(target.lstat().st_ino, before)
        self.assertEqual(target.resolve(), SOURCE)

    def test_conflict_preserved_without_replace(self):
        target = self.config / "DankMaterialShell/plugins/DayzWallpapers"
        target.mkdir(parents=True)
        (target / "custom.qml").write_text("custom")
        with self.assertRaises(FileExistsError):
            self.install()
        self.assertEqual((target / "custom.qml").read_text(), "custom")
        self.assertFalse(self.state.exists())

    def test_replacement_keeps_existing_files(self):
        target = self.config / "DankMaterialShell/plugins/DayzWallpapers"
        target.mkdir(parents=True)
        (target / "custom.qml").write_text("custom")
        self.install(replace=True)
        backups = list((self.config / "DankMaterialShell/backups").glob("*/custom.qml"))
        self.assertEqual(len(backups), 1)
        self.assertEqual(backups[0].read_text(), "custom")
        self.assertTrue(target.is_symlink())

    def test_symlink_backup_is_independent_of_original(self):
        old = Path(self.temp.name) / "old"
        old.mkdir()
        (old / "custom.qml").write_text("custom")
        target = self.config / "DankMaterialShell/plugins/DayzWallpapers"
        target.parent.mkdir(parents=True)
        target.symlink_to(old)
        self.install(replace=True)
        (old / "custom.qml").unlink()
        saved = next((self.config / "DankMaterialShell/backups").glob("*/custom.qml"))
        self.assertEqual(saved.read_text(), "custom")

    def test_missing_dms_is_nonfatal(self):
        with patch.object(installer.shutil, "which", return_value=None):
            installer.enable()
