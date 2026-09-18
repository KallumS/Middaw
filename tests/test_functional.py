"""The chord-function grammar.

Several tests here are regressions for bugs found while building it; each one
was checked against the broken code first.
"""

import random
import unittest

from middaw.functional import (DOMINANT, PREDOMINANT, TONIC, diatonic_chords,
                               generate_progression, related_two,
                               secondary_dominant)
from middaw.prompt import _TONIC_CHORD_RE, progression_is_minor
from middaw.theory import parse_roman, roman_for_degree

MODES = ["major", "minor", "dorian", "mixolydian", "harmonic_minor",
         "melodic_minor", "phrygian", "lydian", "aeolian", "locrian"]


class TestDiatonicChords(unittest.TestCase):
    """Qualities come from stacking thirds inside the mode, not from a table."""

    def test_major(self):
        self.assertEqual([c.symbol for c in diatonic_chords(0, "major", True)],
                         ["Imaj7", "ii7", "iii7", "IVmaj7", "V7", "vi7", "vii0"])

    def test_natural_minor(self):
        self.assertEqual([c.symbol for c in diatonic_chords(0, "minor", True)],
                         ["i7", "ii0", "bIIImaj7", "iv7", "v7", "bVImaj7", "bVII7"])

    def test_dorian_has_a_major_four(self):
        # The major IV is what makes dorian dorian, and nothing says so
        # anywhere in the code - it falls out of the mode.
        symbols = [c.symbol for c in diatonic_chords(0, "dorian", True)]
        self.assertEqual(symbols[3], "IV7")
        self.assertEqual(symbols[0], "i7")

    def test_harmonic_minor_tonic_is_minor_major_seventh(self):
        # Regression: minMaj7 and augMaj7 were missing from the quality table,
        # so both fell through to "major" and harmonic minor's tonic read 'I'.
        symbols = [c.symbol for c in diatonic_chords(0, "harmonic_minor", True)]
        self.assertEqual(symbols[0], "imaj7")
        self.assertEqual(symbols[2], "bIII+maj7")
        self.assertEqual(symbols[4], "V7")
        self.assertEqual(symbols[6], "viio7")

    def test_lydian_fourth_degree_is_sharp_four(self):
        # Regression: naming by semitone alone gave 'bv0'. Six semitones above
        # the tonic is bV in locrian and #IV in lydian; the degree decides.
        symbols = [c.symbol for c in diatonic_chords(0, "lydian", True)]
        self.assertEqual(symbols[3], "#iv0")
        self.assertEqual(roman_for_degree(3, 6), "#IV")

    def test_every_diatonic_chord_parses_in_every_mode(self):
        for mode in MODES:
            for chord in diatonic_chords(0, mode, sevenths=True):
                with self.subTest(mode=mode, symbol=chord.symbol):
                    parsed = parse_roman(chord.symbol, 0, mode)
                    self.assertEqual(parsed.root, chord.root)

    def test_functions_are_assigned_by_degree(self):
        chords = diatonic_chords(0, "major")
        self.assertEqual([c.function for c in chords],
                         [TONIC, PREDOMINANT, TONIC, PREDOMINANT,
                          DOMINANT, TONIC, DOMINANT])


class TestSecondaryDominants(unittest.TestCase):
    def setUp(self):
        self.diatonic = {c.numeral: c for c in diatonic_chords(0, "major")}

    def test_v_of_five_is_written_with_a_bare_numeral(self):
        # Regression: the target's full symbol was used, giving 'V7/V7', which
        # parse_roman cannot read.
        chord = secondary_dominant(0, "major", self.diatonic["V"])
        self.assertEqual(chord.symbol, "V7/V")
        self.assertEqual(chord.label, "V7/V")
        self.assertEqual(chord.root, 2)          # D7 in C major
        self.assertEqual(parse_roman(chord.symbol, 0, "major").quality, "dom7")

    def test_v_of_the_tonic_is_just_v7(self):
        chord = secondary_dominant(0, "major", self.diatonic["I"])
        self.assertEqual(chord.symbol, "V7")
        self.assertEqual(chord.root, 7)

    def test_substitute_dominant_resolves_down_a_semitone(self):
        chord = secondary_dominant(0, "major", self.diatonic["I"], "SubV7")
        self.assertEqual(chord.root, 1)          # Db7 -> C
        self.assertEqual(chord.label, "SubV7")
        self.assertEqual(chord.symbol, "bII7")

    def test_backdoor_dominant_resolves_up_a_whole_step(self):
        chord = secondary_dominant(0, "major", self.diatonic["I"], "bVII7")
        self.assertEqual(chord.root, 10)         # Bb7 -> C
        self.assertEqual(chord.symbol, "bVII7")

    def test_leading_tone_diminished(self):
        chord = secondary_dominant(0, "major", self.diatonic["I"], "viio7")
        self.assertEqual(chord.root, 11)
        self.assertEqual(parse_roman(chord.symbol, 0, "major").quality, "dim7")

    def test_related_two_falls_a_fifth_into_its_dominant(self):
        dominant = secondary_dominant(0, "major", self.diatonic["I"])
        two = related_two(0, "major", dominant)
        self.assertEqual(two.root, 2)            # Dm7 -> G7 -> C
        self.assertEqual(two.symbol, "ii7")
        self.assertEqual(two.function, PREDOMINANT)

    def test_related_two_is_half_diminished_into_a_minor_target(self):
        minor = {c.numeral: c for c in diatonic_chords(0, "minor")}
        dominant = secondary_dominant(0, "minor", minor["iv"])
        two = related_two(0, "minor", dominant)
        self.assertEqual(parse_roman(two.symbol, 0, "minor").quality, "min7b5")


class TestGeneration(unittest.TestCase):
    def _sweep(self, **kwargs):
        for mode in MODES:
            for chromaticism in (0.0, 0.3, 0.6, 1.0):
                for seed in range(20):
                    yield mode, generate_progression(
                        0, mode, kwargs.get("length", 4), chromaticism,
                        kwargs.get("sevenths", 0.5), random.Random(seed))

    def test_every_symbol_it_writes_can_be_parsed(self):
        for mode, progression in self._sweep():
            for chord in progression:
                with self.subTest(mode=mode, symbol=chord.symbol):
                    parse_roman(chord.symbol, 0, mode)

    def test_length_is_respected(self):
        for length in (2, 3, 4, 6, 8):
            for seed in range(10):
                progression = generate_progression(0, "major", length, 0.5, 0.5,
                                                   random.Random(seed))
                self.assertEqual(len(progression), length)

    def test_a_minor_key_never_opens_on_a_major_tonic(self):
        # Regression: a backdoor dominant of ii lands on the tonic root, which
        # put a I7 at the head of a minor loop and blurred the key.
        for mode, progression in self._sweep():
            if not progression[0].symbol[:1].islower():
                continue                          # a major key; nothing to check
            for chord in progression:
                if chord.root == 0 and chord.function != TONIC:
                    self.fail(f"{mode}: {chord.symbol} sits on a minor tonic")

    def test_tonality_agrees_with_the_mode(self):
        from middaw.theory import is_minor
        for mode, progression in self._sweep():
            symbols = [c.symbol for c in progression]
            with self.subTest(mode=mode, progression=symbols):
                self.assertEqual(progression_is_minor(symbols), is_minor(mode))

    def test_chromaticism_actually_changes_the_output(self):
        plain = {tuple(c.symbol for c in generate_progression(
            0, "major", 8, 0.0, 0.5, random.Random(s))) for s in range(40)}
        spicy = {tuple(c.symbol for c in generate_progression(
            0, "major", 8, 1.0, 0.5, random.Random(s))) for s in range(40)}
        self.assertNotEqual(plain, spicy)
        # At zero chromaticism nothing outside the key may appear.
        diatonic = {c.root for c in diatonic_chords(0, "major", True)}
        for progression in plain:
            for symbol in progression:
                self.assertIn(parse_roman(symbol, 0, "major").root, diatonic, symbol)

    def test_secondary_dominants_appear_when_chromaticism_is_high(self):
        labels = set()
        for seed in range(60):
            for chord in generate_progression(0, "major", 8, 1.0, 0.6,
                                              random.Random(seed)):
                labels.add(chord.label.split("/")[0])
        self.assertIn("V7", labels)
        self.assertTrue({"SubV7", "bVII7", "viio7"} & labels, labels)

    def test_it_is_deterministic(self):
        a = [c.symbol for c in generate_progression(0, "minor", 8, 0.6, 0.5,
                                                    random.Random(7))]
        b = [c.symbol for c in generate_progression(0, "minor", 8, 0.6, 0.5,
                                                    random.Random(7))]
        self.assertEqual(a, b)

    def test_long_phrases_do_not_collapse_into_two_chords(self):
        collapsed = 0
        for seed in range(50):
            progression = generate_progression(0, "major", 8, 0.3, 0.5,
                                               random.Random(seed))
            if len({c.root for c in progression}) <= 2:
                collapsed += 1
        self.assertLess(collapsed / 50, 0.3)


class TestNumeralMatching(unittest.TestCase):
    def test_four_is_not_read_as_one(self):
        # Regression: the alternation tried "I" before "IV" with no anchor to
        # force backtracking, so IV7 counted as a major tonic chord.
        self.assertEqual(_TONIC_CHORD_RE.match("IV7").group(2), "IV")
        self.assertEqual(_TONIC_CHORD_RE.match("VII0").group(2), "VII")
        self.assertEqual(_TONIC_CHORD_RE.match("iii7").group(2), "iii")
        self.assertFalse(progression_is_minor(["IV", "V", "I"]))
        self.assertTrue(progression_is_minor(["iv", "V7", "i"]))


if __name__ == "__main__":
    unittest.main()
