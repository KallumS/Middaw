"""Run the JavaScript tests (tests/js) with Node's own test runner.

One command still runs everything: `python3 -m unittest discover -s tests -t .`
Node is not a dependency of the app - the browser runs the same files - so
without it these tests are skipped rather than failed."""

import shutil
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
NODE = shutil.which("node")


@unittest.skipUnless(NODE, "node is not installed")
class TestJavaScript(unittest.TestCase):
    def test_node_suite(self):
        files = sorted(str(p) for p in (ROOT / "tests" / "js").glob("test_*.js"))
        result = subprocess.run([NODE, "--test", *files], cwd=ROOT,
                                capture_output=True, text=True, timeout=600)
        if result.returncode != 0:
            self.fail(result.stdout[-6000:] + result.stderr[-2000:])
