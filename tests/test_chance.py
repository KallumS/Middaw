"""The named probabilities have to be the rates that actually come out.

A number called `step = 0.7` that produces steps 40% of the time is worse than
no number at all, so each one is rolled a few thousand times here and the rate
checked. The tolerances are wide enough that a fixed seed will not fail by
luck and narrow enough to catch a dial that is not connected to anything.
"""

import collections
import random
import unittest

from middaw.accompaniment import bass_pitch, generate_bass
from middaw.cadence import is_conclusive
from middaw.chance import BASS_TONES, MOVES, Chances
from middaw.form import plan_cadences
from middaw.melody import DEFAULT_INTERVALS, MOVE_SIZES, _next_move
from middaw.prompt import parse_prompt
from middaw.render import render
from middaw.theory import parse_roman

ROLLS = 4000
TOLERANCE = 0.03


def rates(counter: collections.Counter) -> dict[str, float]:
    total = sum(counter.values()) or 1
    return {name: count / total for name, count in counter.items()}


class TestTheDiceAreFair(unittest.TestCase):
    def test_a_move_comes_out_at_the_rate_it_was_given(self):
        chances = Chances(step=0.70, skip=0.10, repeat=0.05)
        rng = random.Random(4)
        seen = rates(collections.Counter(chances.move(rng) for _ in range(ROLLS)))
        self.assertAlmostEqual(seen["step"], 0.70, delta=TOLERANCE)
        self.assertAlmostEqual(seen["skip"], 0.10, delta=TOLERANCE)
        self.assertAlmostEqual(seen["repeat"], 0.05, delta=TOLERANCE)
        self.assertAlmostEqual(seen["leap"], 0.15, delta=TOLERANCE)

    def test_the_leap_is_whatever_is_left(self):
        self.assertAlmostEqual(Chances(step=0.5, skip=0.2, repeat=0.1).leap, 0.2)
        self.assertEqual(Chances(step=0.9, skip=0.1, repeat=0.0).leap, 0.0)

    def test_a_bass_tone_comes_out_at_the_rate_it_was_given(self):
        chances = Chances(bass_root=0.5, bass_fifth=0.3)
        rng = random.Random(5)
        seen = rates(collections.Counter(chances.bass_tone(rng) for _ in range(ROLLS)))
        self.assertAlmostEqual(seen["root"], 0.5, delta=TOLERANCE)
        self.assertAlmostEqual(seen["fifth"], 0.3, delta=TOLERANCE)
        self.assertAlmostEqual(seen["third"], 0.2, delta=TOLERANCE)

    def test_shares_over_one_are_scaled_rather_than_ignored(self):
        chances = Chances(step=0.8, skip=0.8, repeat=0.8).clamp()
        self.assertAlmostEqual(chances.step + chances.skip + chances.repeat, 1.0)

    def test_every_name_is_reachable(self):
        rng = random.Random(6)
        moves = {Chances().move(rng) for _ in range(ROLLS)}
        self.assertEqual(moves, set(MOVES))
        tones = {Chances().bass_tone(rng) for _ in range(ROLLS)}
        self.assertEqual(tones, set(BASS_TONES))


class TestTheMelodyObeysThem(unittest.TestCase):
    def test_the_size_of_a_move_matches_its_class(self):
        rng = random.Random(7)
        for _ in range(ROLLS):
            for name, sizes in MOVE_SIZES.items():
                only = Chances(step=0.0, skip=0.0, repeat=0.0)
                setattr(only, "step" if name == "step" else
                        "skip" if name == "skip" else
                        "repeat" if name == "repeat" else "step",
                        0.0 if name == "leap" else 1.0)
                move = _next_move(rng, DEFAULT_INTERVALS, only, previous=0)
                if name == "leap":
                    self.assertIn(move, MOVE_SIZES["leap"])
                    break
                self.assertIn(move, sizes)
                break

    def test_a_melody_steps_as_often_as_it_was_told_to(self):
        """Ask for a stepwise line and a leaping one, and hear the difference."""
        def stepwise_share(step: float) -> float:
            spec = parse_prompt("a folk melody in C major, 32 bars", seed=11)
            spec.chances = Chances(step=step, skip=(1 - step) * 0.4,
                                   repeat=0.08).clamp()
            melody = [t for t in render(spec).song.tracks if t.role == "melody"][0]
            line = sorted(melody.notes, key=lambda n: n.start)
            moves = [abs(b.pitch - a.pitch) for a, b in zip(line, line[1:])]
            moves = [m for m in moves if m > 0]
            return sum(1 for m in moves if m <= 2) / len(moves)

        self.assertGreater(stepwise_share(0.85), stepwise_share(0.15) + 0.15)

    def test_a_leap_turns_back_as_often_as_it_was_told_to(self):
        def turn_back_share(chance: float) -> float:
            spec = parse_prompt("a folk melody in C major, 32 bars", seed=12)
            spec.chances = Chances(step=0.35, skip=0.2, repeat=0.05,
                                   leap_turns_back=chance)
            melody = [t for t in render(spec).song.tracks if t.role == "melody"][0]
            line = sorted(melody.notes, key=lambda n: n.start)
            leaps = turned = 0
            for first, second, third in zip(line, line[1:], line[2:]):
                jump = second.pitch - first.pitch
                if abs(jump) < 5:
                    continue
                leaps += 1
                after = third.pitch - second.pitch
                turned += after == 0 or (after > 0) != (jump > 0)
            return turned / leaps if leaps else 1.0

        self.assertGreater(turn_back_share(0.95), turn_back_share(0.05))


class TestTheBassObeysThem(unittest.TestCase):
    def test_the_root_share_follows_the_dial(self):
        """Measured on the bass line itself, against the chord it is under."""
        spans = []
        symbols = ["I", "vi", "IV", "V7"] * 40
        for bar, symbol in enumerate(symbols):
            spans.append((bar * 4.0, 4.0, parse_roman(symbol, 0, "major")))

        def root_share(chance: float) -> float:
            spec = parse_prompt("a pop tune in C major", seed=13)
            spec.chances = Chances(bass_root=chance, bass_fifth=(1 - chance) * 0.6)
            spec.pattern = "block"
            spec.density = 0.4                 # one bass note per chord
            notes = generate_bass(spec, spans, random.Random(3))
            roots = {chord.root for _s, _l, chord in spans}
            by_bar = {}
            for note in notes:
                by_bar.setdefault(int(note.start // 4), note)
            hits = sum(1 for bar, note in by_bar.items()
                       if note.pitch % 12 == spans[bar][2].root)
            return hits / len(by_bar)

        self.assertAlmostEqual(root_share(0.95), 0.95, delta=0.06)
        self.assertAlmostEqual(root_share(0.30), 0.30, delta=0.08)

    def test_the_bass_is_always_monophonic(self):
        """It overlapped itself before: a four-beat chord played the root for
        3.8 beats and the fifth from beat 2."""
        for prompt in ("a pop tune in G", "a hymn in F", "bebop jazz piano in Bb",
                       "minimal techno", "a waltz in D"):
            for seed in (1, 2, 3):
                bass = [t for t in render(parse_prompt(prompt, seed=seed)).song.tracks
                        if t.role == "bass"][0]
                line = sorted(bass.notes, key=lambda n: n.start)
                for first, second in zip(line, line[1:]):
                    self.assertLessEqual(first.start + first.duration,
                                         second.start + 1e-6,
                                         f"{prompt}: bass overlaps itself")

    def test_a_cadence_lands_in_root_position(self):
        """However the dice fall, a phrase ends with its root in the bass.

        Without this a piece could close on a second-inversion tonic, which is
        not a cadence - and our own key detection, which reads the last chord,
        called such a piece a fifth away from where it was.
        """
        spans = [(0.0, 4.0, parse_roman(s, 0, "major"))
                 for s in ("I", "vi", "IV", "V7", "I")]
        spans = [(i * 4.0, 4.0, chord) for i, (_s, _l, chord) in enumerate(spans)]
        spec = parse_prompt("a pop tune in C major", seed=14)
        spec.chances = Chances(bass_root=0.0, bass_fifth=1.0)   # never the root
        for seed in range(20):
            notes = generate_bass(spec, spans, random.Random(seed))
            last = max(notes, key=lambda n: n.start)
            self.assertEqual(last.pitch % 12, spans[-1][2].root)

    def test_a_chosen_tone_is_a_tone_of_the_chord(self):
        for symbol in ("I", "V7", "ii7", "bVI", "viio7", "IVmaj7"):
            chord = parse_roman(symbol, 0, "major")
            for tone in BASS_TONES:
                pitch = bass_pitch(chord, 36, tone)
                self.assertIn(pitch % 12, chord.pitch_classes, f"{symbol} {tone}")
                self.assertTrue(36 <= pitch < 48, f"{symbol} {tone}: {pitch}")


class TestTheCadenceObeysThem(unittest.TestCase):
    def test_coming_home_follows_the_dial(self):
        layout = [("A", "verse"), ("A'", "verse"), ("B", "contrast"),
                  ("C", "third tune"), ("D", "fourth tune"), ("E", "last")]

        def home_share(chance: float) -> float:
            home = total = 0
            for seed in range(200):
                plan = plan_cadences(layout, random.Random(seed),
                                     chances=Chances(cadence_lands_home=chance,
                                                     twin_answers=0.0))
                for cadence in plan[:-1]:
                    total += 1
                    home += is_conclusive(cadence)
            return home / total

        self.assertGreater(home_share(0.9), home_share(0.1) + 0.3)

    def test_the_piece_still_comes_home_at_the_end(self):
        """However open its phrases are, the last one closes."""
        layout = [("A", "verse"), ("B", "contrast"), ("A'", "return")]
        for seed in range(50):
            plan = plan_cadences(layout, random.Random(seed),
                                 chances=Chances(cadence_lands_home=0.0))
            self.assertTrue(is_conclusive(plan[-1]), plan)


if __name__ == "__main__":
    unittest.main()
