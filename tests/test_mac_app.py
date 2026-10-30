"""The Mac app: built, valid, pointing at this checkout, with an icon.

Built here into a temporary folder; on a Mac the icon becomes an .icns, off
one it stays a PNG, which is what this checks."""

import plistlib
import shutil
import struct
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MAC = ROOT / "tools" / "mac"


@unittest.skipUnless(shutil.which("bash") and shutil.which("sed"), "needs bash and sed")
class TestMacApp(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        subprocess.run(["bash", str(MAC / "make_app.sh"), cls.tmp.name], check=True,
                       capture_output=True, env={"PATH": "/usr/bin:/bin", "PYTHON": sys.executable})
        cls.app = Path(cls.tmp.name) / "Middaw.app"

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def test_info_plist_names_an_executable_that_exists(self):
        info = plistlib.loads((self.app / "Contents" / "Info.plist").read_bytes())
        self.assertEqual(info["CFBundleName"], "Middaw")
        exe = self.app / "Contents" / "MacOS" / info["CFBundleExecutable"]
        self.assertTrue(exe.is_file())
        self.assertTrue(exe.stat().st_mode & 0o111, "the launcher must be executable")
        self.assertEqual(info["LSMinimumSystemVersion"], "11.0")   # every Apple silicon Mac

    def test_launcher_points_at_this_checkout_and_parses(self):
        exe = (self.app / "Contents" / "MacOS" / "Middaw").read_text()
        self.assertIn(f'ROOT="{ROOT}"', exe)
        self.assertNotIn("__MIDDAW_ROOT__", exe)
        subprocess.run(["bash", "-n", str(self.app / "Contents" / "MacOS" / "Middaw")], check=True)
        self.assertIn("--quit-when-idle", exe)

    def test_icon_is_a_1024_png(self):
        res = self.app / "Contents" / "Resources"
        icns, png = res / "Middaw.icns", res / "Middaw.png"
        if icns.exists():
            self.assertEqual(icns.read_bytes()[:4], b"icns")
            return
        data = png.read_bytes()
        self.assertEqual(data[:8], b"\x89PNG\r\n\x1a\n")
        self.assertEqual(struct.unpack(">II", data[16:24]), (1024, 1024))


if __name__ == "__main__":
    unittest.main()
