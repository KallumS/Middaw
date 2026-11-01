"""Fidelity tests for the ScaleView Pro port.

Every chord case here is lifted from `tests/test_scaleview_pro.lua` in
github.com/KallumS/scaleview-for-reaper, at the head that carries df4ea43
(Starting Blocks' roots), in the suite's order and under the key the suite
had selected. If the port drifts from the original engine, these fail.
Comments are the Lua suite's own. Its three "Simplify Note Names" cases are
left out: Middaw has no such option.
"""

import unittest
from itertools import combinations

from middaw.scaleview import Key, SCALES, detect_chord, key_for, spell_as

C3, C4 = 48, 60


def chord(notes, key=None):
    """Play MIDI notes, as ScaleView is played: the lowest one is the bass, and
    a pitch class sounding in two octaves counts as doubled."""
    return detect_chord(notes, min(notes), Key(*key) if key else None)


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


class TestScaleViewProSuite(unittest.TestCase):
    """`expect(...)` in the Lua suite: (key, notes, name). None is no scale."""

    CASES = [
    # the requested examples
    (None, [60, 63, 67, 75], 'Cmin'),  # C Eb G with Eb doubled an octave up
    (None, [60, 63, 67, 70], 'Cmin7'),  # C Eb G Bb
    (None, [59, 61, 66], 'Bsus2'),  # B C# F#
    # triads and sevenths
    (None, [60, 64, 67], 'C'),
    (None, [60, 63, 67], 'Cmin'),
    (None, [60, 63, 66], 'Cdim'),
    (None, [60, 64, 68], 'Caug'),
    (None, [60, 65, 67], 'Csus4'),
    (None, [60, 62, 67], 'Csus2'),
    (None, [60, 64, 67, 71], 'Cmaj7'),
    (None, [60, 64, 67, 70], 'C7'),
    (None, [60, 63, 66, 70], 'Cmin7b5'),
    (None, [60, 63, 66, 69], 'Cdim7'),
    (None, [60, 64, 67, 69], 'C6'),
    (None, [60, 62, 64, 67], 'Cadd9'),
    (None, [60, 62, 64, 67, 70], 'C9'),
    # inversions
    (None, [52, 60, 67], 'C/E'),  # E in the bass
    (None, [43, 60, 64], 'C/G'),  # G in the bass
    (None, [48, 52, 55, 59], 'Cmaj7'),  # root position stays plain
    # a doubled root of the key takes the bass
    (None, [52, 55, 60, 72], 'C'),  # E G C C - the root in two octaves, so no slash
    (None, [52, 55, 60], 'C/E'),  # one C and it is a first inversion again
    (None, [52, 55, 60, 71], 'Cmaj7/E'),  # doubling something else changes nothing
    (None, [53, 57, 62, 74], 'Dmin/F'),  # D is not a 1st, 3rd or 5th degree of C major
    (("D", "minor"), [53, 57, 62, 74], 'Dmin'),  # in D minor it is one, so the slash comes off
    (("D", "minor"), [53, 57, 62], 'Dmin/F'),  # and an undoubled root is still an inversion
    # what the Scaler comparison moved
    # Blocks builds these notes as D7b9 over its seventh, never on C - was Cdim9
    (None, [60, 62, 63, 66, 69], 'D7b9/C'),
    # Am6 and F#m7b5 are both Blocks chords: the half-diminished, as before
    (None, [60, 76, 78, 81], 'F#min7b5/C'),
    (None, [60, 63, 67, 69], 'Cmin6'),  # but a minor sixth in root position stays
    (None, [62, 63, 67, 69], 'D#maj7b5/D'),  # was Dsus4b9, which has no third in it
    (None, [64, 70, 74], 'A#(b5)/E'),  # was E7b5(no3), which has none either
    (None, [65, 69, 71], 'F(b5)'),  # and the case that rule came from still holds
    # a third-less shape over a perfect fifth is a real voicing, and stays
    (None, [60, 67, 70], 'C7(no3)'),
    # both fifths sounding
    (None, [60, 64, 66, 68, 71], 'Cmaj7#5#11'),  # was Cmaj7b5b13
    (None, [60, 74, 76, 78, 80, 82], 'Caug9#11'),  # the whole-tone six, was C9b5b13
    (None, [60, 64, 66, 71], 'Cmaj7b5'),  # one flattened fifth is unchanged
    (None, [60, 64, 68, 71], 'Cmaj7#5'),  # and so is one raised
    # altered dominants
    (None, [48, 64, 68, 70, 73], 'Caug7b9'),  # C7#5b9, was A#min9b5/C
    (None, [48, 64, 66, 70, 73], 'C7b5b9'),  # was F#7#11/C
    (None, [48, 64, 66, 70, 75], 'C7b5#9'),  # was D#min6b9/C
    (None, [48, 64, 70, 73, 80], 'Caug7b9'),  # C7b9b13, was A#min9b5/C
    (None, [48, 64, 68, 70, 75], 'Caug7#9'),  # and C7#5#9 already read right
    # the half-diminished is not a dominant, and is unchanged
    (None, [48, 63, 66, 70, 74], 'Cmin9b5'),
    # a draw goes to the reading without a slash
    (None, [48, 62, 67, 70], 'C7sus2'),  # was GminAdd11/C
    # Blocks builds C D F G only as its quartal tetrad on D - was Csus4Add9
    (None, [48, 62, 65, 67], 'Dmin7(11)/C'),
    (None, [45, 60, 64, 67], 'Amin7'),  # a real difference in cost still decides
    # C6 against Amin7 - the bass decides
    (None, [45, 60, 64, 67], 'Amin7'),  # A in the bass
    (None, [48, 64, 67, 69], 'C6'),  # C in the bass
    (None, [43, 60, 64, 69], 'Amin7/G'),  # neither: the commoner chord, with a slash
    # Blocks' roots
    (None, [60, 63, 66, 71], 'CminMaj7b5'),  # Blocks' diminished major seventh on C - was Baddb9/C
    # I6 and vi7 over C are both Blocks chords: the cheaper reading
    (None, [48, 64, 67, 69], 'C6'),
    (None, [60, 65, 67], 'Csus4'),  # and Csus4 stays Csus4, though Blocks builds Fsus2 over C too
    (None, [71, 77], 'B(b5)(no3)'),  # B F is Blocks' fifth on B in C major
    (None, [65, 71], 'B(b5)(no3)/F'),  # and over F, its first inversion
    (None, [60, 62, 65, 67], 'Dmin7(11)/C'),  # C D F G is Blocks' quartal tetrad on D, in any key
    # a ninth chord's fourth inversion puts its ninth in the bass
    (None, [64, 74, 78, 81, 84], 'D9/E'),
    # Blocks' altered dominant on C, inverted high - was A#min11b5/C
    (None, [60, 61, 63, 64, 68, 70], 'Caug7b9#9'),
    # in Db major Blocks builds no chord on B: an interval, read out
    (("Db", "major"), [71, 77], 'F B'),
    # a chord type counts on any root, in any key
    (("Db", "major"), [60, 62, 65, 67], 'Dmin7(11)/C'),
    (("Db", "major"), [61, 65, 68], 'Db'),  # Blocks' I in Db major
    (None, [61, 65, 68], 'C#'),  # no Blocks chord on C# in C major - the reader names it, sharp
    # one and two notes
    (None, [60], 'C'),
    (None, [60, 67], 'C5'),  # a bare fifth
    (None, [60, 64], 'Cmaj(no5)'),  # a major third is a chord
    (None, [71, 74], 'Bmin(no5)'),  # and so is a minor third
    (None, [64, 72], 'Cmaj(no5)/E'),  # the lower note still names the bass
    (None, [60, 66], 'C F#'),  # a tritone is an interval: name the notes
    (None, [60, 62], 'C D'),  # so is a second
    (None, [60, 65], 'F5/C'),  # a fourth is a fifth upside down, as before
    # spelling follows the key
    (("Gb", "major"), [54, 58, 61], 'Gb'),  # Gb Bb Db in Gb major
    (("Gb", "major"), [54, 58, 61, 65], 'Gbmaj7'),
    (("F#", "major"), [54, 58, 61], 'F#'),  # the same three notes in F# major
    # keys whose notes need double accidentals
    (("Gb", "blues"), [60, 64, 69], 'Amin/C'),  # was: Bbbmin/Dbb
    (("A#", "harmonic_minor"), [60, 63, 69], 'Adim/C'),  # was: Gxdim/B#
    (("Gb", "major"), [54, 58, 61], 'Gb'),  # single accidentals are untouched
    (("Cb", "major"), [59, 63, 66], 'Cb'),  # and Cb major still reads Cb
    # extensions and thinner voicings
    (("C#", "major"), [60, 63, 65], 'CminAdd11'),  # B# D# E#; Scaler: C min add 11
    (("Eb", "minor"), [61, 66, 67], 'Gmaj7b5(no3)/Db'),  # Db Gb G; Scaler: G maj7 (no3 b5) / C#
    # C Db Gb A; Scaler: F# min #11 / C
    (("Eb", "harmonic_minor"), [60, 61, 66, 69], 'Gbmin#11/C'),
    (None, [60, 62, 64], 'Cadd9'),  # an added ninth with no fifth
    (None, [60, 64, 65], 'Cadd11'),  # an added eleventh with no fifth
    (None, [60, 64, 65, 67], 'Cadd11'),  # and with one
    (None, [60, 64, 66, 67], 'Cadd#11'),
    (None, [60, 67, 70], 'C7(no3)'),  # a seventh with no third has to say so
    (None, [60, 64, 69], 'Amin/C'),  # C E A is an inversion, not C6
    (None, [60, 63, 69], 'Adim/C'),  # C Eb A likewise
    # chords the table could not name
    (None, [60, 64, 67, 68, 70], 'C7b13'),
    (None, [60, 64, 66, 67, 71], 'Cmaj7#11'),
    (None, [60, 62, 64, 66, 67, 71], 'Cmaj9#11'),
    (None, [60, 64, 67, 69, 70], 'C7(13)'),  # no ninth in it, so the number cannot claim one
    (None, [60, 62, 64, 67, 69, 70], 'C13'),  # and with the ninth, it can
    (None, [60, 63, 67, 69, 70], 'Cmin7(13)'),
    (None, [60, 61, 64, 67, 69, 70], 'C13b9'),
    (None, [60, 62, 64, 66, 67, 69, 70], 'C13#11'),
    # Blocks' 13b9b5 on F#; Blocks has no 7#9#11 - was C7#9#11
    (None, [60, 63, 64, 66, 67, 70], 'F#13b5b9/C'),
    (None, [60, 62, 64, 65, 67], 'Cadd9Add11'),
    (None, [60, 62, 63, 65, 67], 'CminAdd9Add11'),
    # five notes: Hutchinson 31.4 prints exactly this as Cm7(11)
    (None, [60, 63, 65, 67, 70], 'Cmin7(11)'),
    # six notes, the ninth among them: the same list prints Cm11
    (None, [60, 62, 63, 65, 67, 70], 'Cmin11'),
    (None, [60, 63, 65, 66, 70], 'D#min6/9/C'),  # Blocks' m6/9 on Eb - was Cmin7b5(11)
    # a third outranks a quality with none
    (None, [69, 71, 77], 'F(b5)/A'),  # E# A B over A; Scaler: F maj(b5) / A
    (None, [65, 69, 71], 'F(b5)'),  # and rooted, where the bass does not decide it
    (None, [60, 64, 66, 71], 'Cmaj7b5'),  # the same shape carrying a seventh
    # the complete triad wins
    # C D Eb Gb Cb; Scaler: Cb maj b9 #9 / C - Alt says D13b9/C
    (("Gb", "major"), [60, 62, 63, 66, 71], 'Cbaddb9#9/C'),
    # alterations belong to the chord under them
    # a b13 is not a concession: this is Cmaj7 inverted, with a ninth
    (("C", "major"), [64, 67, 71, 72, 74], 'Cmaj9/E'),
    # but a b13 over a flat fifth still means a wrong root
    (("C", "major"), [64, 67, 70, 72, 74], 'C9/E'),
    (("C", "major"), [60, 64, 68, 71], 'Cmaj7#5'),  # and one over a sharp fifth likewise
    # a number may not claim a ninth that is not there
    # the flattened ninth fills the stack, so the thirteenth still names it
    (("C", "major"), [60, 61, 64, 67, 69, 70], 'C13b9'),
    # both sevenths at once
    (("C", "major"), [55, 59, 62, 66, 77], 'G7(maj7)'),  # G B D F with an F# over it
    # a flat sixth is a b6 until a seventh arrives
    (("C", "major"), [60, 64, 67, 68], 'G#maj7#5/C'),  # Blocks' maj7#5 on Ab
    (("C", "major"), [60, 64, 67, 68, 70], 'C7b13'),  # and a b13 once one does
    # a sixth does not swallow an altered fifth
    (("C", "major"), [60, 62, 64, 68, 69], 'C6/9#5'),  # was C6/9, which claims a natural fifth
    (("C", "major"), [60, 64, 70], 'C7'),  # a shell voicing is still a seventh chord
    (("C", "major"), [60, 67, 70], 'C7(no3)'),  # but a missing third changes the quality
    # Blocks builds C D G B as Gadd11 over its eleventh, and has no Cmaj7sus2 - was Cmaj7sus2
    (("C", "major"), [60, 62, 67, 71], 'Gadd11/C'),
    # the scale does not overrule the notes
    (("C", "major"), [54, 58, 61], 'F#'),  # F# A# C# is F# major, however far from C major
    (("C", "major"), [60, 64, 67, 70], 'C7'),  # and a dominant 7 stays a dominant 7
    (None, [60, 64, 67, 70], 'C7'),  # the same with no scale selected
    (("Gb", "major"), [54, 58, 61], 'Gb'),  # chord root spelled for the key
    (("A#", "harmonic_minor"), [60, 63, 69], 'Adim/C'),  # and back to key spelling
]


    def test_every_case(self):
        for key, notes, want in self.CASES:
            with self.subTest(key=key, notes=notes):
                self.assertEqual(chord(notes, key), want)

    def test_releasing_and_adding_notes(self):
        # 7) and 8): C E G less its third is C5; add a Bb and it is C7.
        self.assertEqual(chord([C4, C4 + 7]), "C5")
        self.assertEqual(chord([C4, C4 + 4, C4 + 7, C4 + 10]), "C7")


class TestKeyChords(unittest.TestCase):
    """df4ea43 makes the reading depend on the key's own chords."""

    def test_the_same_notes_in_two_keys(self):
        self.assertEqual(chord([71, 77]), "B(b5)(no3)")
        self.assertEqual(chord([71, 77], ("Db", "major")), "F B")
        self.assertEqual(chord([61, 65, 68]), "C#")
        self.assertEqual(chord([61, 65, 68], ("Db", "major")), "Db")

    def test_pitch_classes_alone_are_never_doubled(self):
        # The doubled-root rule needs the notes; pitch classes cannot carry it.
        self.assertEqual(detect_chord([4, 7, 0], 4), "C/E")
        self.assertEqual(detect_chord([52, 55, 60, 72], 52), "C")


class TestSweeps(unittest.TestCase):
    """6g and 6h of the Lua suite, over every three- and four-note set."""

    @staticmethod
    def voicings():
        for size in (3, 4):
            for combo in combinations(range(12), size):
                yield [C4 + pc for pc in combo]

    def test_no_voicing_is_read_out_as_notes(self):
        unnamed = [v for v in self.voicings() if " " in chord(v)]
        self.assertEqual(unnamed, [])

    def test_no_scale_names_exactly_as_c_major(self):
        differ = [v for v in self.voicings() if chord(v) != chord(v, ("C", "major"))]
        self.assertEqual(differ, [])

    def test_every_voicing_of_three_to_five_notes_gets_a_name(self):
        for size in (3, 4, 5):
            for combo in combinations(range(12), size):
                name = detect_chord(combo, combo[0])
                self.assertTrue(name, combo)

    def test_empty_selection(self):
        self.assertIsNone(detect_chord([]))


if __name__ == "__main__":
    unittest.main()
