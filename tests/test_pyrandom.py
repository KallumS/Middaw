"""runtime/composer/pyrandom.js draws what Python's random.Random draws.

The composer's music is a function of its seed, so a port of it is only the
same composer if every seed gives the same numbers: ints, huge ints and the
string seeds render.py uses (through SHA-512, as Python's version 2 seeding
does), and every method the composer calls."""

import json
import random
import shutil
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
NODE = shutil.which("node")
SEEDS = [0, 1, 42, 2**31 - 1, 123456789012345678901234567890, -7, "12345:A", "x", "héllo:B", "987654321:C"]

JS = """
const R = require(%r);
const seeds = JSON.parse(process.argv[1]);
const out = seeds.map((s) => {
  const r = new R.Random(typeof s === 'string' && s.startsWith('int:') ? BigInt(s.slice(4)) : s);
  const v = [...Array(5)].map(() => r.random()).concat([1, 7, 32, 33, 53].map((k) => r.getrandbits(k)));
  v.push(r.randrange(10), r.randrange(3, 1000), r.randrange(2 ** 31), r.choice('abcdefg'));
  v.push(...r.choices(['a', 'b', 'c'], [0.2, 0.5, 0.3], 4));
  v.push(r.uniform(2, 9), r.gauss(0, 1), r.gauss(5, 2), r.gauss(0, 1));
  const xs = [...Array(10).keys()]; r.shuffle(xs); v.push(xs);
  for (let i = 0; i < 2000; i++) v.push(r.random());
  return v;
});
console.log(JSON.stringify(out));
"""


def python_draws(seed):
    r = random.Random(seed)
    v = [r.random() for _ in range(5)] + [r.getrandbits(k) for k in (1, 7, 32, 33, 53)]
    v += [r.randrange(10), r.randrange(3, 1000), r.randrange(2**31), r.choice("abcdefg")]
    v += r.choices(["a", "b", "c"], weights=[0.2, 0.5, 0.3], k=4)
    v += [r.uniform(2, 9), r.gauss(0, 1), r.gauss(5, 2), r.gauss(0, 1)]
    xs = list(range(10))
    r.shuffle(xs)
    v.append(xs)
    v += [r.random() for _ in range(2000)]
    return v


@unittest.skipUnless(NODE, "node is not installed")
class TestPyRandom(unittest.TestCase):
    def test_every_seed_draws_the_same_numbers(self):
        arg = [("int:%d" % s) if isinstance(s, int) and abs(s) > 2**53 else s for s in SEEDS]
        out = subprocess.run([NODE, "-e", JS % str(ROOT / "runtime" / "composer" / "pyrandom.js"), json.dumps(arg)],
                             capture_output=True, text=True, check=True).stdout
        for seed, got in zip(SEEDS, json.loads(out)):
            self.assertEqual(got, python_draws(seed), seed)


if __name__ == "__main__":
    unittest.main()
