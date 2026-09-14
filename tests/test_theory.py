import unittest

from middaw.theory import (Chord, degree_to_pitch, nearest_degree, note_name,
                           parse_note_name, parse_roman, scale_pitch_classes)


class TestNoteNames(unittest.TestCase):
    def test_round_trip(self):
        self.assertEqual(parse_note_name("C"), 0)
        self.assertEqual(parse_note_name("f#"), 6)
        self.assertEqual(parse_note_name("Bb"), 10)
        self.assertEqual(note_name(60), "C4")
        self.assertEqual(note_name(69), "A4")

    def test_unknown_name(self):
        with self.assertRaises(ValueError):
            parse_note_name("H")


class TestRomanNumerals(unittest.TestCase):
    def test_major_triads(self):
        self.assertEqual(parse_roman("I", 0, "major").pitch_classes, (0, 4, 7))
        self.assertEqual(parse_roman("vi", 0, "major").pitch_classes, (9, 0, 4))
        self.assertEqual(parse_roman("V7", 0, "major").pitch_classes, (7, 11, 2, 5))

    def test_minor_and_borrowed(self):
        self.assertEqual(parse_roman("i", 9, "minor").pitch_classes, (9, 0, 4))
        self.assertEqual(parse_roman("bVII", 0, "minor").pitch_classes, (10, 2, 5))
        self.assertEqual(parse_roman("iv7", 0, "minor").quality, "min7")

    def test_secondary_dominant(self):
        chord = parse_roman("V7/vi", 0, "major")
        self.assertEqual(chord.quality, "dom7")
        self.assertEqual(chord.root, 4)          # E7 resolving to Am

    def test_rejects_garbage(self):
        with self.assertRaises(ValueError):
            parse_roman("Q9", 0, "major")


class TestVoicing(unittest.TestCase):
    def test_voicing_stays_in_range(self):
        chord = parse_roman("Imaj7", 3, "major")
        notes = chord.voice(low=48, high=72)
        self.assertTrue(all(46 <= n <= 76 for n in notes), notes)
        self.assertEqual(len(set(notes)), len(notes))
        self.assertTrue(all(n % 12 in chord.pitch_classes for n in notes))

    def test_nearest_tone_is_close(self):
        chord = parse_roman("I", 0, "major")
        self.assertLessEqual(abs(chord.nearest_tone(61) - 61), 2)
        self.assertIn(chord.nearest_tone(61) % 12, chord.pitch_classes)


class TestScaleDegrees(unittest.TestCase):
    def test_degree_round_trip(self):
        scale = scale_pitch_classes(2, "minor")
        for degree in range(-7, 15):
            pitch = degree_to_pitch(scale, 50, degree)
            self.assertEqual(nearest_degree(scale, 50, pitch), degree)

    def test_octave_spacing(self):
        scale = scale_pitch_classes(0, "major")
        self.assertEqual(degree_to_pitch(scale, 60, 7) - degree_to_pitch(scale, 60, 0), 12)


if __name__ == "__main__":
    unittest.main()
