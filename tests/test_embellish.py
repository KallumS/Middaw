"""Non-chord tones.

The point of these tests is that a device is only a passing tone if it is
approached and left like one. Every test re-derives the classification from the
notes that were actually written, rather than trusting the label.
"""

import random
import unittest
from collections import Counter

from middaw.embellish import (ANTICIPATION, APPOGGIATURA, ESCAPE, LEAP, NEIGHBOR,
                              PASSING, RETARDATION, SUSPENSION, _classify,
                              embellish)
from middaw.melody import generate_melody
from middaw.prompt import parse_prompt
from middaw.render import _chords_by_bar, build_chord_spans, generate
from middaw.theory import scale_pitch_classes

STEPWISE = (PASSING, NEIGHBOR, ESCAPE, APPOGGIATURA)


def _line(prompt, seed=4, ornament=None):
    spec = parse_prompt(prompt, seed=seed)
    if ornament is not None:
        spec.ornament = ornament
    rng = random.Random(seed)
    spans = build_chord_spans(spec, rng)
    skeleton = generate_melody(spec, _chords_by_bar(spans), rng)
    notes, applied = embellish(spec, spans, skeleton, random.Random(seed + 1))
    return spec, spans, skeleton, notes, applied


class TestClassification(unittest.TestCase):
    """The definitions, applied literally."""

    def test_the_table(self):
        cases = [
            (2, 2, PASSING), (-1, -2, PASSING), (1, 1, PASSING),
            (2, -2, NEIGHBOR), (-1, 1, NEIGHBOR),
            (5, -1, APPOGGIATURA), (-7, 2, APPOGGIATURA), (4, 1, APPOGGIATURA),
            (2, -5, ESCAPE), (-1, 4, ESCAPE),
            (1, 0, ANTICIPATION), (-2, 0, ANTICIPATION),
            (0, -1, SUSPENSION), (0, -2, SUSPENSION),
            (0, 2, RETARDATION), (0, 1, RETARDATION),
        ]
        for approach, departure, want in cases:
            with self.subTest(approach=approach, departure=departure):
                self.assertEqual(_classify(approach, departure), want)

    def test_things_that_are_not_non_chord_tones(self):
        self.assertIsNone(_classify(5, 5))      # leap in, leap out
        self.assertIsNone(_classify(0, 5))      # held, then leaps away
        self.assertIsNone(_classify(0, 0))      # never moves
        self.assertIsNone(_classify(2, 5))      # step in, leap on in the same way
        self.assertIsNone(_classify(None, 2))

    def test_a_step_is_up_to_a_major_second(self):
        self.assertEqual(LEAP, 3)
        self.assertEqual(_classify(2, 2), PASSING)      # two whole steps
        self.assertEqual(_classify(3, -1), APPOGGIATURA)  # a minor third is a leap


class TestDevicesAreWhatTheyClaim(unittest.TestCase):
    def test_stepwise_devices_verify_against_their_definition(self):
        checked = Counter()
        for prompt in ("baroque invention in C major", "a romantic nocturne in Eb",
                       "ornamented celtic jig", "classical piece in D minor"):
            for seed in range(3):
                _spec, _spans, _skel, notes, applied = _line(prompt, seed)
                by_start = sorted(notes, key=lambda n: (n.start, n.pitch))
                for item in applied:
                    if item.kind not in STEPWISE:
                        continue
                    index = next((i for i, n in enumerate(by_start)
                                  if abs(n.start - item.beat) < 1e-6
                                  and n.pitch == item.pitch), None)
                    self.assertIsNotNone(index, f"{item} missing from the line")
                    if index == 0 or index + 1 >= len(by_start):
                        continue
                    before, after = by_start[index - 1], by_start[index + 1]
                    with self.subTest(prompt=prompt, kind=item.kind):
                        self.assertEqual(
                            _classify(item.pitch - before.pitch,
                                      after.pitch - item.pitch),
                            item.kind,
                            f"{before.pitch} -> {item.pitch} -> {after.pitch}")
                    checked[item.kind] += 1
        self.assertGreater(sum(checked.values()), 30, checked)
        for kind in STEPWISE:
            self.assertIn(kind, checked, f"{kind} never produced")

    def test_a_suspension_is_dissonant_at_the_change_and_resolves_down(self):
        from middaw.embellish import _chord_at
        found = 0
        for prompt in ("baroque invention in C major", "a romantic nocturne in Eb",
                       "classical piece in D minor"):
            for seed in range(4):
                _spec, spans, _skel, notes, applied = _line(prompt, seed)
                by_start = sorted(notes, key=lambda n: (n.start, n.pitch))
                for item in applied:
                    if item.kind not in (SUSPENSION, RETARDATION):
                        continue
                    held = next((n for n in by_start
                                 if n.pitch == item.pitch
                                 and n.start < item.beat < n.end + 1e-6), None)
                    if held is None:
                        continue
                    chord = _chord_at(spans, item.beat)
                    with self.subTest(kind=item.kind):
                        # It is only a suspension if it is a non-chord tone
                        # where it lands.
                        self.assertNotIn(item.pitch % 12, chord.pitch_classes)
                        after = next((n for n in by_start if n.start >= held.end - 1e-6
                                      and n.start > held.start), None)
                        if after is not None:
                            move = after.pitch - item.pitch
                            self.assertTrue(0 < abs(move) < LEAP, move)
                            if item.kind == SUSPENSION:
                                self.assertLess(move, 0, "a suspension resolves down")
                            else:
                                self.assertGreater(move, 0, "a retardation resolves up")
                    found += 1
        self.assertGreater(found, 0, "no suspensions were produced")

    def test_an_anticipation_arrives_at_the_next_note_early(self):
        found = 0
        for seed in range(6):
            _spec, _spans, _skel, notes, applied = _line("a pop tune in G major", seed)
            by_start = sorted(notes, key=lambda n: (n.start, n.pitch))
            for item in applied:
                if item.kind != ANTICIPATION:
                    continue
                index = next((i for i, n in enumerate(by_start)
                              if abs(n.start - item.beat) < 1e-6
                              and n.pitch == item.pitch), None)
                if index is None or index + 1 >= len(by_start):
                    continue
                self.assertEqual(by_start[index + 1].pitch, item.pitch,
                                 "an anticipation is left by the same note")
                found += 1
        self.assertGreater(found, 0, "no anticipations were produced")


class TestItDoesNotBreakTheMusic(unittest.TestCase):
    def test_decoration_is_diatonic(self):
        for prompt in ("a folk melody in D dorian", "baroque invention in C major",
                       "ornamented celtic jig in A minor"):
            spec, _spans, _skel, notes, applied = _line(prompt)
            scale = set(scale_pitch_classes(spec.tonic, spec.mode))
            for item in applied:
                with self.subTest(prompt=prompt, kind=item.kind):
                    self.assertIn(item.pitch % 12, scale,
                                  "embellishment must stay in the key")
            self.assertTrue(all(21 <= n.pitch <= 108 for n in notes))

    def test_a_non_chord_tone_is_never_a_chord_tone(self):
        from middaw.embellish import _chord_at
        for prompt in ("baroque invention in C major", "jazz piano in Bb major"):
            _spec, spans, _skel, _notes, applied = _line(prompt)
            for item in applied:
                if item.kind in (ANTICIPATION,):
                    continue              # it belongs to the *next* chord
                chord = _chord_at(spans, item.beat)
                with self.subTest(kind=item.kind):
                    self.assertNotIn(item.pitch % 12, chord.pitch_classes)

    def test_the_cadence_note_is_left_alone(self):
        for prompt in ("baroque invention in C major", "a romantic nocturne in Eb"):
            _spec, _spans, skeleton, notes, _applied = _line(prompt)
            self.assertEqual(max(n.start for n in notes),
                             max(n.start for n in skeleton),
                             "the last note should not move")

    def test_ornament_controls_how_much(self):
        _s, _sp, _sk, _n, none = _line("baroque invention in C major", 4, ornament=0.0)
        _s, _sp, _sk, _n, lots = _line("baroque invention in C major", 4, ornament=1.0)
        self.assertEqual(none, [])
        self.assertGreater(len(lots), 10)

    def test_a_short_line_is_left_alone(self):
        spec = parse_prompt("a riff", seed=1)
        self.assertEqual(embellish(spec, [], [], random.Random(1)), ([], []))

    def test_notes_stay_playable(self):
        for prompt in ("baroque invention in C major", "ornamented celtic jig",
                       "a romantic nocturne in Eb", "gospel piano in Eb"):
            result = generate(prompt, seed=2)
            for note in result.song.notes:
                self.assertTrue(21 <= note.pitch <= 108)
                self.assertGreater(note.duration, 0)
                self.assertGreaterEqual(note.start, 0)

    def test_embellished_output_still_round_trips_through_midi(self):
        from middaw.midi import bytes_to_song
        result = generate("baroque invention in C major", seed=2)
        self.assertGreater(len(result.embellishments), 0)
        self.assertEqual(len(bytes_to_song(result.midi).notes),
                         len(result.song.notes))

    def test_it_is_deterministic(self):
        a = generate("a romantic nocturne in Eb", seed=11)
        b = generate("a romantic nocturne in Eb", seed=11)
        self.assertEqual(a.midi, b.midi)
        self.assertEqual([e.to_dict() for e in a.embellishments],
                         [e.to_dict() for e in b.embellishments])


if __name__ == "__main__":
    unittest.main()
