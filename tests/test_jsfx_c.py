"""The family's JSFX compiled to C, held to runtime/jsfx/jsfx.js.

tools/jsfx2c.js translates each device to C for the native app. These tests
build tools/jsfx_c_host.c over that C and hold it to tools/jsfx_host.js:
Midi Evolver's own engine checks must pass on it, and every device, driven by
the same random sliders, notes, controllers, transport and audio, must end up
with the same variables, send the same MIDI and play the same samples.

The two can differ in the last bit of a sine or a logarithm (V8's maths
library is not the Mac's), so audio and variables are compared to within a
millionth, MIDI exactly."""

import math
import os
import random
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
NODE = shutil.which("node")
CC = shutil.which(os.environ.get("CC", "cc")) or shutil.which("clang") or shutil.which("gcc")
DEV = ROOT / "family" / "devices"
DEVICES = ["AutoCC.jsfx", "Instrument-Creator.jsfx", "MIDI_Production_Center.jsfx",
           "Midi Evolver.jsfx", "Reverberator.jsfx", "TransientShuffler.jsfx",
           "Midular.jsfx", "ReeseBasser.jsfx"]

_host = None


def c_host():
    """Builds the C host once per run."""
    global _host
    if _host is None:
        out = Path(tempfile.mkdtemp()) / "jsfx_c_host"
        c = ROOT / "mac" / "Sources" / "CJSFX"
        subprocess.run([CC, "-std=gnu11", "-O1", "-I", str(c), "-o", str(out),
                        str(ROOT / "tools" / "jsfx_c_host.c"), str(c / "jsfx_rt.c")]
                       + sorted(str(p) for p in (c / "devices").glob("*.c")) + ["-lm"],
                       check=True, capture_output=True, text=True)
        _host = out
    return _host


def sliders(device):
    """The device's sliders, as the JS runtime reads its header."""
    script = ("const J=require(%r),fs=require('fs'),path=require('path');"
              "const f=J.parseFile(fs.readFileSync(%r,'utf8'),n=>fs.readFileSync(path.join(%r,n),'utf8'));"
              "console.log(JSON.stringify(f.sliders))") % (str(ROOT / "runtime" / "jsfx" / "jsfx.js"), str(DEV / device), str(DEV))
    import json
    return json.loads(subprocess.run([NODE, "-e", script], check=True, capture_output=True, text=True).stdout)


def scenario(device, seed):
    """A session: the device's sliders moved about, notes played and held,
    controllers, the transport, audio in, and everything read back."""
    rng = random.Random(seed)
    cmds = ["tempo %d 4 4" % rng.choice([90, 120, 133]), "transport 1 0"]
    sl = [s for s in sliders(device) if not s["hidden"]]
    held = []
    for step in range(40):
        roll = rng.random()
        if roll < 0.25 and sl:
            s = rng.choice(sl)
            lo, hi = s["min"], s["max"]
            v = rng.uniform(min(lo, hi), max(lo, hi))
            if s["step"]:
                v = lo + round((v - lo) / s["step"]) * s["step"]
            cmds.append("slider %d %r" % (s["index"], v))
        elif roll < 0.5:
            k = rng.randint(36, 84)
            cmds.append("note %d %d" % (k, rng.randint(30, 127)))
            held.append(k)
        elif roll < 0.6 and held:
            cmds.append("noteoff %d" % held.pop(rng.randrange(len(held))))
        elif roll < 0.67:
            cmds.append("cc %d %d" % (rng.choice([1, 11, 64, 74]), rng.randint(0, 127)))
        elif roll < 0.72:
            cmds.append("input square %d %r" % (rng.choice([37, 100, 480]), rng.choice([0.1, 0.5, 0.9])))
        elif roll < 0.75:
            cmds.append("transport %d %r" % (rng.choice([0, 1, 1, 5]), rng.choice([0, 4, 7.5])))
        cmds.append("block %d" % rng.randint(1, 6))
        cmds.append("audio")
        if step % 8 == 7:
            cmds += ["vars", "midi"]
    if device in ("Midi Evolver.jsfx", "MIDI_Production_Center.jsfx", "AutoCC.jsfx"):
        cmds += ["reload", "block 4", "audio"]
    cmds += ["vars", "midi", "sync"]
    return cmds


def run(host, device, cmds, seed):
    argv = [NODE, str(ROOT / "tools" / "jsfx_host.js")] if host == "js" else [str(c_host())]
    r = subprocess.run(argv + [str(DEV / device)], input="\n".join(cmds) + "\n", env=dict(os.environ, JSFX_SEED=str(1000 + seed), JSFX_CLOCK="samples"),
                       capture_output=True, text=True, timeout=600)
    if r.returncode != 0:
        raise AssertionError("%s host failed on %s: %s" % (host, device, r.stderr[-2000:]))
    return r.stdout.splitlines()


def close(a, b):
    if a == b:
        return True
    try:
        x, y = float(a), float(b)
    except ValueError:
        return False
    if math.isnan(x) and math.isnan(y):
        return True
    return abs(x - y) <= 1e-6 * max(1.0, abs(x), abs(y))


@unittest.skipUnless(NODE and CC, "needs node and a C compiler")
class TestCompiledDevices(unittest.TestCase):
    def test_generated_code_is_up_to_date(self):
        r = subprocess.run([NODE, str(ROOT / "tools" / "jsfx2c.js"), "--check"], capture_output=True, text=True)
        self.assertEqual(r.returncode, 0, r.stderr)

    def test_midi_evolver_engine_checks_pass_on_the_c(self):
        r = subprocess.run([sys.executable, str(ROOT / "tests" / "family" / "midi_evolver_enginecheck.py"),
                            "--host", str(c_host()), "--jsfx", str(DEV / "Midi Evolver.jsfx")],
                           capture_output=True, text=True, timeout=900)
        tail = r.stdout.strip().splitlines()[-1] if r.stdout.strip() else r.stderr
        self.assertEqual(r.returncode, 0, r.stdout[-4000:] + r.stderr[-2000:])
        self.assertIn(" 0 failed", tail)

    def test_every_device_matches_the_js_runtime(self):
        for device in DEVICES:
            for seed in range(3):
                with self.subTest(device=device, seed=seed):
                    cmds = scenario(device, seed)
                    js, c = run("js", device, cmds, seed), run("c", device, cmds, seed)
                    self.assertEqual(len(js), len(c), "different number of answers")
                    sound = 0.0
                    for i, (a, b) in enumerate(zip(js, c)):
                        if a.startswith("VARS"):
                            # the C compiles every function up front, so it can
                            # have more variables; every one the JS has must agree
                            jv = dict(kv.split("=", 1) for kv in a.split()[1:])
                            cv = dict(kv.split("=", 1) for kv in b.split()[1:])
                            bad = [(k, jv[k], cv.get(k)) for k in jv if k not in cv or not close(jv[k], cv[k])]
                            self.assertFalse(bad, "line %d: variables differ: %s" % (i, bad[:8]))
                            continue
                        if a.startswith("AUDIO"):
                            xs, ys = a.split()[1:], b.split()[1:]
                            sound = max([sound] + [abs(float(x)) for x in xs])
                            bad = [(k, x, y) for k, (x, y) in enumerate(zip(xs, ys)) if not close(x, y)]
                            self.assertFalse(bad, "line %d: audio differs: %s" % (i, bad[:8]))
                            continue
                        self.assertEqual(a, b, "line %d" % i)


if __name__ == "__main__":
    unittest.main()
