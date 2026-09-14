"""Fidelity tests for the ScaleView Pro port.

Every case here is lifted from `tests/test_scaleview_pro.lua` in
github.com/KallumS/scaleview-for-reaper. If the port drifts from the original
engine, these fail. Comments name the reasoning the Lua suite records.
"""

import unittest

from middaw.scaleview import Key, SCALES, detect_chord, key_for, spell_as

C3, C4 = 48, 60


def chord(notes, key=None):
    return detect_chord([n % 12 for n in notes], min(notes) % 12, key)


class TestSpelling(unittest.TestCase):
    def test_gb_major_spells_flats_including_cb(self):
        key = Key("Gb", "major")
        ordered = sorted(key.active, key=lambda pc: (pc - key.tonic) % 12)
        self.assertEqual([key.note_name(pc) for pc in ordered],
                         ["Gb", "Ab", "Bb", "Cb", "Db", "Eb", "F"])
        self.assertTrue(key.uses_flats)

    def test_fsharp_major_spells_sharps(self):
        key = Key("F#", "major")
        ordered = sorted(key.active, key=lambda pc: (pc - key.tonic) % 12)
        self.assertEqual([key.note_name(pc) for pc in ordered],
                         ["F#", "G#", "A#", "B", "C#", "D#", "E#"])
        self.assertFalse(key.uses_flats)

    def test_double_accidentals_are_spelled(self):
        self.assertEqual(spell_as(5, 9), "A")       # A natural
        self.assertEqual(spell_as(4, 9), "Gx")      # G double sharp
        self.assertEqual(spell_as(1, 0), "Dbb")     # D double flat

    def test_key_for_picks_the_conventional_spelling(self):
        self.assertEqual(key_for(10, "major").root.name, "Bb")
        self.assertEqual(key_for(6, "minor").root.name, "F#")
        self.assertEqual(key_for(3, "major").root.name, "Eb")

    def test_every_mode_spells_its_whole_scale(self):
        for mode in SCALES:
            key = key_for(0, mode)
            self.assertEqual(len(key.names), 12, mode)


class TestTriadsAndSevenths(unittest.TestCase):
    CASES = [
        ([C4, C4 + 3, C4 + 7, C4 + 15], "Cmin"),
        ([C4, C4 + 3, C4 + 7, C4 + 10], "Cmin7"),
        ([59, 61, 66], "Bsus2"),
        ([C4, C4 + 4, C4 + 7], "C"),
        ([C4, C4 + 3, C4 + 7], "Cmin"),
        ([C4, C4 + 3, C4 + 6], "Cdim"),
        ([C4, C4 + 4, C4 + 8], "Caug"),
        ([C4, C4 + 5, C4 + 7], "Csus4"),
        ([C4, C4 + 2, C4 + 7], "Csus2"),
        ([C4, C4 + 4, C4 + 7, C4 + 11], "Cmaj7"),
        ([C4, C4 + 4, C4 + 7, C4 + 10], "C7"),
        ([C4, C4 + 3, C4 + 6, C4 + 10], "Cmin7b5"),
        ([C4, C4 + 3, C4 + 6, C4 + 9], "Cdim7"),
        ([C4, C4 + 4, C4 + 7, C4 + 9], "C6"),
        ([C4, C4 + 2, C4 + 4, C4 + 7], "Cadd9"),
        ([C4, C4 + 2, C4 + 4, C4 + 7, C4 + 10], "C9"),
    ]

    def test_cases(self):
        for notes, want in self.CASES:
            with self.subTest(notes=notes):
                self.assertEqual(chord(notes), want)


class TestInversions(unittest.TestCase):
    def test_bass_is_named_after_a_slash(self):
        self.assertEqual(chord([52, C4, 67]), "C/E")
        self.assertEqual(chord([43, C4, 64]), "C/G")
        self.assertEqual(chord([C3, C3 + 4, C3 + 7, C3 + 11]), "Cmaj7")

    def test_the_bass_decides_c6_against_amin7(self):
        self.assertEqual(chord([45, C4, 64, 67]), "Amin7")
        self.assertEqual(chord([C3, 64, 67, 69]), "C6")
        self.assertEqual(chord([43, C4, 64, 69]), "Amin7/G")

    def test_a_sixth_without_its_fifth_stays_an_inversion(self):
        self.assertEqual(chord([C4, C4 + 4, C4 + 9]), "Amin/C")
        self.assertEqual(chord([C4, C4 + 3, C4 + 9]), "Adim/C")


class TestOneAndTwoNotes(unittest.TestCase):
    def test_short_selections(self):
        self.assertEqual(chord([C4]), "C")
        self.assertEqual(chord([C4, C4 + 7]), "C5")
        self.assertEqual(chord([C4, C4 + 4]), "C E")


class TestKeyAwareChordSymbols(unittest.TestCase):
    def test_symbols_follow_the_key(self):
        self.assertEqual(chord([54, 58, 61], Key("Gb", "major")), "Gb")
        self.assertEqual(chord([54, 58, 61, 65], Key("Gb", "major")), "Gbmaj7")
        self.assertEqual(chord([54, 58, 61], Key("F#", "major")), "F#")
        self.assertEqual(chord([59, 63, 66], Key("Cb", "major")), "Cb")

    def test_chord_symbols_never_use_double_accidentals(self):
        # Gb minor blues spells these Dbb, Fb, Bbb; the chord is still Amin/C.
        self.assertEqual(chord([C4, C4 + 4, C4 + 9], Key("Gb", "blues")), "Amin/C")
        # A# harmonic minor spells the root Gx and the bass B#; both fall back.
        self.assertEqual(chord([C4, C4 + 3, C4 + 9], Key("A#", "harmonic_minor")),
                         "Adim/C")

    def test_the_scale_itself_keeps_its_double_accidental(self):
        self.assertEqual(Key("A#", "harmonic_minor").note_name(9), "Gx")


class TestThinAndExtendedVoicings(unittest.TestCase):
    def test_reported_from_reaper(self):
        self.assertEqual(chord([C4, C4 + 3, C4 + 5], Key("C#", "major")), "CminAdd11")
        self.assertEqual(chord([61, 66, 67], Key("Eb", "minor")), "Gmaj7b5(no3)/Db")
        self.assertEqual(chord([C4, 61, 66, 69], Key("Eb", "harmonic_minor")),
                         "Gbmin#11/C")

    def test_incomplete_voicings(self):
        self.assertEqual(chord([C4, C4 + 2, C4 + 4]), "Cadd9")
        self.assertEqual(chord([C4, C4 + 4, C4 + 5]), "Cadd11")
        self.assertEqual(chord([C4, C4 + 4, C4 + 5, C4 + 7]), "Cadd11")
        self.assertEqual(chord([C4, C4 + 4, C4 + 6, C4 + 7]), "Cadd#11")
        self.assertEqual(chord([C4, C4 + 7, C4 + 10]), "C7(no3)")

    def test_chords_a_lookup_table_could_not_name(self):
        cases = [
            ([C4, C4 + 4, C4 + 7, C4 + 8, C4 + 10], "C7b13"),
            ([C4, C4 + 4, C4 + 6, C4 + 7, C4 + 11], "Cmaj7#11"),
            ([C4, C4 + 2, C4 + 4, C4 + 6, C4 + 7, C4 + 11], "Cmaj9#11"),
            ([C4, C4 + 4, C4 + 7, C4 + 9, C4 + 10], "C7(13)"),
            ([C4, C4 + 2, C4 + 4, C4 + 7, C4 + 9, C4 + 10], "C13"),
            ([C4, C4 + 3, C4 + 7, C4 + 9, C4 + 10], "Cmin7(13)"),
            ([C4, C4 + 1, C4 + 4, C4 + 7, C4 + 9, C4 + 10], "C13b9"),
            ([C4, C4 + 2, C4 + 4, C4 + 6, C4 + 7, C4 + 9, C4 + 10], "C13#11"),
            ([C4, C4 + 3, C4 + 4, C4 + 6, C4 + 7, C4 + 10], "C7#9#11"),
            ([C4, C4 + 2, C4 + 4, C4 + 5, C4 + 7], "Cadd9Add11"),
            ([C4, C4 + 2, C4 + 3, C4 + 5, C4 + 7], "CminAdd9Add11"),
            ([C4, C4 + 3, C4 + 5, C4 + 7, C4 + 10], "Cmin7(11)"),
            ([C4, C4 + 2, C4 + 3, C4 + 5, C4 + 7, C4 + 10], "Cmin11"),
            ([C4, C4 + 3, C4 + 5, C4 + 6, C4 + 10], "Cmin7b5(11)"),
        ]
        for notes, want in cases:
            with self.subTest(want=want):
                self.assertEqual(chord(notes), want)

    def test_a_third_outranks_a_quality_with_none(self):
        self.assertEqual(chord([69, 71, 77]), "F(b5)/A")
        self.assertEqual(chord([65, 69, 71]), "F(b5)")
        self.assertEqual(chord([C4, C4 + 4, C4 + 6, C4 + 11]), "Cmaj7b5")

    def test_the_complete_triad_wins(self):
        self.assertEqual(chord([C4, C4 + 2, C4 + 3, C4 + 6, C4 + 11],
                               Key("Gb", "major")), "Cbaddb9#9/C")

    def test_alterations_belong_to_the_chord_under_them(self):
        self.assertEqual(chord([64, 67, 71, 72, 74]), "Cmaj9/E")
        self.assertEqual(chord([64, 67, 70, 72, 74]), "C9/E")


class TestRobustness(unittest.TestCase):
    def test_every_voicing_of_three_to_five_notes_gets_a_name(self):
        from itertools import combinations
        for size in (3, 4, 5):
            for combo in combinations(range(12), size):
                name = detect_chord(combo, combo[0])
                self.assertTrue(name, combo)

    def test_empty_selection(self):
        self.assertIsNone(detect_chord([]))


if __name__ == "__main__":
    unittest.main()
