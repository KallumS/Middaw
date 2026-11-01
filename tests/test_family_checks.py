"""Midi Evolver's own engine checks, run unchanged against Middaw's JSFX.

tests/family/midi_evolver_enginecheck.py was written for a ysfx host;
tools/jsfx_host.js speaks the same commands over runtime/jsfx/jsfx.js."""

import os
import shutil
import stat
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
NODE = shutil.which("node")


@unittest.skipUnless(NODE, "node is not installed")
class TestMidiEvolverEngine(unittest.TestCase):
    def test_every_engine_check_passes(self):
        with tempfile.TemporaryDirectory() as tmp:
            host = Path(tmp) / "host"
            host.write_text(f'#!/bin/sh\nexec "{NODE}" "{ROOT / "tools" / "jsfx_host.js"}" "$@"\n')
            host.chmod(host.stat().st_mode | stat.S_IEXEC)
            result = subprocess.run(
                [sys.executable, str(ROOT / "tests" / "family" / "midi_evolver_enginecheck.py"),
                 "--host", str(host), "--jsfx", str(ROOT / "family" / "devices" / "Midi Evolver.jsfx")],
                capture_output=True, text=True, timeout=900)
        tail = result.stdout.strip().splitlines()[-1] if result.stdout.strip() else result.stderr
        self.assertEqual(result.returncode, 0, result.stdout[-4000:] + result.stderr[-2000:])
        self.assertIn(" 0 failed", tail)
