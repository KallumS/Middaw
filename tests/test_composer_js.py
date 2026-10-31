"""The composer in JavaScript (runtime/composer/) is the composer.

The app composes in JavaScriptCore, with no Python. runtime/composer/ is a
line-for-line port of middaw/, and this holds it there: every word in the
vocabulary as a prompt, mixed prompts with keys, meters, tempos and lengths
stated, each with its own seed, must give the same answer `python3 -m middaw
--json` gives - the spec, the five parts note for note, the chords, the
sections, the ornaments, the summary.

**A change to middaw/ is a change to runtime/composer/ too.** This test is
what says so. Numbers are compared to within a billionth, because two maths
libraries may disagree in the last bit of a sine; everything else exactly."""

import json
import random
import shutil
import subprocess
import unittest
from pathlib import Path

from middaw.corpus.stats import load_corpus_priors
from middaw.prompt import parse_prompt
from middaw.render import render

ROOT = Path(__file__).resolve().parent.parent
NODE = shutil.which("node")

JS = """
const fs = require('fs'), path = require('path'), root = process.argv[1];
for (const f of ['py', 'pyrandom', 'core', 'functional', 'music', 'render']) require(path.join(root, 'runtime', 'composer', f + '.js'));
const C = globalThis.MiddawComposer;
const vocab = (n) => JSON.parse(fs.readFileSync(path.join(root, 'data', 'vocab', n), 'utf8'));
C.load(vocab('tags.json'), vocab('drums.json'));
const cases = JSON.parse(fs.readFileSync(0, 'utf8'));
process.stdout.write(JSON.stringify(cases.map(([p, s]) => C.compose(p, s))));
"""

EXTRAS = ["in Eb major", "in c# dorian", "at 140 bpm", "7/8", "6/8", "3/4", "32 bars", "12 bars", "2 minutes",
          "30 seconds", "no drums", "with drums", "in Bb harmonic minor", "in g mixolydian", "5/4", "in F lydian",
          "in d blues scale", "seed 99"]


def cases():
    tags = json.loads((ROOT / "data" / "vocab" / "tags.json").read_text(encoding="utf-8"))
    words = []
    for group in ("genres", "moods", "descriptors", "scales", "forms", "voices", "roles"):
        for tag, entry in tags.get(group, {}).items():
            words.append(tag.replace("_", " "))
            words += entry.get("synonyms", [])[:1]
    rng = random.Random(2026)
    out = [[w, rng.randrange(1, 2**31)] for w in words]
    for _ in range(120):
        prompt = " ".join(rng.sample(words, rng.randint(1, 3)))
        if rng.random() < 0.6:
            prompt += " " + rng.choice(EXTRAS)
        out.append([prompt, rng.randrange(1, 2**31)])
    return out


def differs(a, b, path=""):
    if isinstance(a, dict) and isinstance(b, dict):
        for k in sorted(set(a) | set(b)):
            if k not in a or k not in b:
                return path + "/" + k + " is missing on one side"
            d = differs(a[k], b[k], path + "/" + k)
            if d:
                return d
        return None
    if isinstance(a, list) and isinstance(b, list):
        if len(a) != len(b):
            return "%s: %d items against %d" % (path, len(a), len(b))
        for i, (x, y) in enumerate(zip(a, b)):
            d = differs(x, y, "%s[%d]" % (path, i))
            if d:
                return d
        return None
    numbers = (int, float)
    if isinstance(a, numbers) and isinstance(b, numbers) and not isinstance(a, bool) and not isinstance(b, bool):
        return None if a == b or abs(a - b) <= 1e-9 * max(1.0, abs(a), abs(b)) else "%s: %r against %r" % (path, a, b)
    return None if a == b else "%s: %r against %r" % (path, a, b)


@unittest.skipUnless(NODE, "node is not installed")
class TestComposerInJavaScript(unittest.TestCase):
    def test_every_prompt_composes_the_same_music(self):
        todo = cases()
        priors = load_corpus_priors(ROOT / "data" / "corpus")
        expected = []
        for prompt, seed in todo:
            spec = parse_prompt(prompt, seed=seed)
            data = render(spec, priors=priors).to_dict()
            data["summary"] = spec.summary()
            expected.append(data)
        out = subprocess.run([NODE, "-e", JS, str(ROOT)], input=json.dumps(todo), capture_output=True,
                             text=True, timeout=600)
        self.assertEqual(out.returncode, 0, out.stderr[-3000:])
        got = json.loads(out.stdout)
        self.assertEqual(len(got), len(todo))
        wrong = [(case, d) for case, a, b in zip(todo, expected, got) for d in [differs(a, b)] if d]
        self.assertFalse(wrong, "%d of %d differ, first: %s" % (len(wrong), len(todo), wrong[:3]))

    def test_the_corpus_is_empty_so_the_port_needs_no_priors(self):
        # render() uses corpus priors only when data/corpus has entries; the
        # port has none, so it is only the same composer while that holds.
        self.assertEqual(load_corpus_priors(ROOT / "data" / "corpus").entries, 0)


if __name__ == "__main__":
    unittest.main()
