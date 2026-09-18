"""Reading notation, and measuring ourselves against it."""

import tempfile
import unittest
import zipfile
from pathlib import Path

from middaw.corpus.analyse import detect_key, name_window
from middaw.corpus.measure import (_detected_transposition, analyst_chord,
                                   measure_harmony, measure_key,
                                   melodic_profile, pair_files,
                                   profile_distance, run)
from middaw.corpus.notation import (parse_romantext_key, read_kern,
                                    read_musicxml, read_romantext)
from middaw.scaleview import key_for
from middaw.song import Note


def part(id_, name, measures, key_mode="major", fifths=0):
    body = "".join(measures)
    return f'''  <score-part id="{id_}"><part-name>{name}</part-name></score-part>''', \
           f'''<part id="{id_}">{body}</part>'''


def measure(number, notes, attributes="", implicit=False):
    mark = ' implicit="yes"' if implicit else ""
    return f'<measure number="{number}"{mark}>{attributes}{notes}</measure>'


def attributes(divisions=1, fifths=0, mode="major", beats=4, beat_type=4):
    return (f"<attributes><divisions>{divisions}</divisions>"
            f"<key><fifths>{fifths}</fifths><mode>{mode}</mode></key>"
            f"<time><beats>{beats}</beats><beat-type>{beat_type}</beat-type></time>"
            f"</attributes>")


def note(step, octave, duration, alter=0, chord=False, rest=False, tie=None):
    if rest:
        return f"<note><rest/><duration>{duration}</duration></note>"
    alteration = f"<alter>{alter}</alter>" if alter else ""
    chord_tag = "<chord/>" if chord else ""
    ties = f'<tie type="{tie}"/>' if tie else ""
    return (f"<note>{chord_tag}<pitch><step>{step}</step>{alteration}"
            f"<octave>{octave}</octave></pitch>"
            f"<duration>{duration}</duration><voice>1</voice>{ties}</note>")


def score_xml(parts):
    declarations = "".join(p[0] for p in parts)
    bodies = "".join(p[1] for p in parts)
    return (f'<?xml version="1.0" encoding="UTF-8"?><score-partwise>'
            f'<part-list>{declarations}</part-list>{bodies}</score-partwise>')


class TestMusicXML(unittest.TestCase):
    def read(self, xml, suffix=".xml"):
        directory = Path(self.enterContext(tempfile.TemporaryDirectory()))
        path = directory / f"score{suffix}"
        if suffix == ".mxl":
            with zipfile.ZipFile(path, "w") as archive:
                archive.writestr("META-INF/container.xml", "<container/>")
                archive.writestr("score.xml", xml)
        else:
            path.write_text(xml, encoding="utf-8")
        return read_musicxml(path)

    def test_notes_are_placed_in_beats(self):
        xml = score_xml([part("P1", "Soprano", [
            measure(1, note("C", 4, 2) + note("D", 4, 1) + note("E", 4, 1),
                    attributes(divisions=1)),
            measure(2, note("F", 4, 4)),
        ])])
        score = self.read(xml)
        self.assertEqual([(n.start, n.duration, n.pitch) for n in score.notes],
                         [(0.0, 2.0, 60), (2.0, 1.0, 62), (3.0, 1.0, 64),
                          (4.0, 4.0, 65)])
        self.assertEqual(score.meter, (4, 4))
        self.assertEqual(score.measure_starts, {1: 0.0, 2: 4.0})

    def test_divisions_scale_durations(self):
        xml = score_xml([part("P1", "S", [
            measure(1, note("C", 4, 4) + note("D", 4, 4), attributes(divisions=4)),
        ])])
        score = self.read(xml)
        self.assertEqual([n.duration for n in score.notes], [1.0, 1.0])

    def test_a_chord_shares_its_onset(self):
        xml = score_xml([part("P1", "S", [
            measure(1, note("C", 4, 2) + note("E", 4, 2, chord=True)
                    + note("G", 4, 2, chord=True) + note("F", 4, 2),
                    attributes()),
        ])])
        score = self.read(xml)
        self.assertEqual([(n.start, n.pitch) for n in score.notes],
                         [(0.0, 60), (0.0, 64), (0.0, 67), (2.0, 65)])

    def test_tied_notes_become_one_note(self):
        xml = score_xml([part("P1", "S", [
            measure(1, note("C", 4, 4, tie="start"), attributes()),
            measure(2, note("C", 4, 4, tie="stop")),
        ])])
        score = self.read(xml)
        self.assertEqual(len(score.notes), 1)
        self.assertEqual(score.notes[0].duration, 8.0)

    def test_rests_advance_time_without_sounding(self):
        xml = score_xml([part("P1", "S", [
            measure(1, note("C", 4, 2, rest=True) + note("G", 4, 2), attributes()),
        ])])
        score = self.read(xml)
        self.assertEqual([(n.start, n.pitch) for n in score.notes], [(2.0, 67)])

    def test_a_minor_key_signature_is_read_as_minor(self):
        xml = score_xml([part("P1", "S", [
            measure(1, note("A", 3, 4), attributes(fifths=0, mode="minor")),
        ])])
        score = self.read(xml)
        self.assertEqual((score.tonic, score.mode), (9, "minor"))

    def test_the_first_part_settles_the_key(self):
        """Parts disagree in 156 of the 410 Bach chorales music21 ships.

        The soprano is marked minor and the lower three major, on the same
        signature. Letting the last part win calls a third of the collection
        major that is not, which then measures as a key-detection failure that
        is really a reading failure.
        """
        xml = score_xml([
            part("P1", "Soprano", [measure(1, note("A", 3, 4),
                                           attributes(fifths=0, mode="minor"))]),
            part("P2", "Bass", [measure(1, note("A", 2, 4),
                                        attributes(fifths=0, mode="major"))]),
        ])
        score = self.read(xml)
        self.assertEqual(score.mode, "minor")

    def test_a_pickup_bar_counts_its_beats_from_the_end(self):
        xml = score_xml([part("P1", "S", [
            measure(0, note("G", 4, 1), attributes(), implicit=True),
            measure(1, note("C", 4, 4)),
        ])])
        score = self.read(xml)
        self.assertEqual(score.measure_lengths[0], 1.0)
        self.assertEqual(score.measure_beat(0, 4.0), 0.0)   # the pickup beat
        self.assertEqual(score.measure_beat(1, 1.0), 1.0)

    def test_a_zipped_score_reads_the_same(self):
        xml = score_xml([part("P1", "S", [measure(1, note("C", 4, 4), attributes())])])
        self.assertEqual(len(self.read(xml, suffix=".mxl").notes), 1)


KERN = """!!!COM: Bach, Johann Sebastian
!!!SCT: BWV 269
**kern	**kern
*I"Bass	*I"Soprano
*k[f#]	*k[f#]
*G:	*G:
*M3/4	*M3/4
*MM100	*MM100
4GG	4g
=1	=1
4G	2g
4E	.
4F#	4dd
=2	=2
2D	4b
4C	[2a
=3	=3
8r	2a]
8AA	.
2GG	4g
*-	*-
"""


class TestKern(unittest.TestCase):
    def read(self, text=KERN):
        directory = Path(self.enterContext(tempfile.TemporaryDirectory()))
        path = directory / "chorale.krn"
        path.write_text(text, encoding="utf-8")
        return read_kern(path)

    def test_pitches(self):
        from middaw.corpus.notation import kern_pitch
        self.assertEqual(kern_pitch("c"), 60)
        self.assertEqual(kern_pitch("cc"), 72)
        self.assertEqual(kern_pitch("C"), 48)
        self.assertEqual(kern_pitch("CC"), 36)
        self.assertEqual(kern_pitch("f#"), 66)
        self.assertEqual(kern_pitch("e-"), 63)

    def test_durations(self):
        from middaw.corpus.notation import kern_duration
        self.assertEqual(kern_duration("4"), 1.0)
        self.assertEqual(kern_duration("8"), 0.5)
        self.assertEqual(kern_duration("4."), 1.5)
        self.assertEqual(kern_duration("2"), 2.0)
        self.assertEqual(kern_duration("1"), 4.0)

    def test_a_duration_is_found_behind_a_tie_or_phrase_mark(self):
        """"[2a" is a half note starting a tie, not a token without a duration.

        Anchoring the match to the front of the token drops every tied note in
        the file, and a chorale is mostly tied notes.
        """
        from middaw.corpus.notation import kern_duration
        self.assertEqual(kern_duration("[2a"), 2.0)
        self.assertEqual(kern_duration("(4b"), 1.0)
        self.assertEqual(kern_duration("{8cc"), 0.5)

    def test_metadata(self):
        score = self.read()
        self.assertEqual(score.meter, (3, 4))
        self.assertEqual(score.tempo, 100.0)
        self.assertEqual((score.tonic, score.mode), (7, "major"))
        self.assertEqual(sorted(score.parts), ["Bass", "Soprano"])

    def test_each_spine_keeps_its_own_clock(self):
        """A null token means the note before it is still sounding."""
        score = self.read()
        soprano = score.parts["Soprano"]
        self.assertEqual([(n.start, n.duration) for n in soprano[:3]],
                         [(0.0, 1.0), (1.0, 2.0), (3.0, 1.0)])
        bass = score.parts["Bass"]
        self.assertEqual([(n.start, n.duration) for n in bass[:4]],
                         [(0.0, 1.0), (1.0, 1.0), (2.0, 1.0), (3.0, 1.0)])

    def test_a_tie_makes_one_note(self):
        score = self.read()
        held = [n for n in score.parts["Soprano"] if n.duration == 4.0]
        self.assertEqual(len(held), 1)          # [2a ... 2a] is one note

    def test_rests_take_time_without_sounding(self):
        score = self.read()
        bass = score.parts["Bass"]
        self.assertEqual(bass[-2].start, 7.5)   # after the eighth rest
        self.assertEqual(bass[-1].start, 8.0)

    def test_barlines_become_measure_starts(self):
        score = self.read()
        self.assertEqual(score.measure_starts[1], 1.0)
        self.assertEqual(score.measure_starts[2], 4.0)


ROMAN_TEXT = """Composer: J. S. Bach
BWV: 269
Title: A test
Time Signature: 3/4

m0 b3 G: I
m1 b2 IV6 b3 V6
m2 I b2 V || b3 vi
m2var1 I b2 iii
m3 e: iv b2 V7/V
m4-5 = m1
"""


class TestRomanText(unittest.TestCase):
    def read(self, text=ROMAN_TEXT):
        directory = Path(self.enterContext(tempfile.TemporaryDirectory()))
        path = directory / "analysis.rntxt"
        path.write_text(text, encoding="utf-8")
        return read_romantext(path)

    def test_headers_and_meter(self):
        analysis = self.read()
        self.assertEqual(analysis.headers["BWV"], "269")
        self.assertEqual(analysis.meter, (3, 4))

    def test_measures_beats_and_keys(self):
        chords = self.read().chords
        self.assertEqual((chords[0].measure, chords[0].beat, chords[0].numeral,
                          chords[0].key), (0, 3.0, "I", "G"))
        self.assertEqual((chords[1].measure, chords[1].beat, chords[1].numeral),
                         (1, 2.0, "IV6"))
        self.assertEqual(chords[3].beat, 1.0)          # a bare measure starts at b1
        self.assertEqual([c.key for c in chords][-2:], ["e", "e"])

    def test_barlines_are_not_chords(self):
        self.assertNotIn("||", [c.numeral for c in self.read().chords])

    def test_variants_and_copies_are_counted_not_guessed(self):
        self.assertEqual(self.read().skipped, 2)

    def test_key_names(self):
        self.assertEqual(parse_romantext_key("G"), (7, "major"))
        self.assertEqual(parse_romantext_key("bb"), (10, "minor"))
        self.assertEqual(parse_romantext_key("F#"), (6, "major"))


class TestMeasuring(unittest.TestCase):
    def test_figured_bass_is_stripped_before_reading_a_numeral(self):
        from middaw.corpus.notation import AnalysedChord
        chord = AnalysedChord(measure=1, beat=1.0, numeral="V6/5", key="C")
        self.assertEqual(analyst_chord(chord, (0, "major")).root, 7)

    def test_a_tonicisation_survives_it(self):
        from middaw.corpus.notation import AnalysedChord
        chord = AnalysedChord(measure=1, beat=1.0, numeral="V4/3/V", key="C")
        self.assertEqual(analyst_chord(chord, (0, "major")).root, 2)

    def test_a_transposed_edition_is_detected_not_counted_wrong(self):
        class Fake:
            def __init__(self, root):
                self.root = root
        readings = [(None, Fake(0), None, 2), (None, Fake(7), None, 9),
                    (None, Fake(5), None, 7), (None, Fake(0), None, 2)]
        self.assertEqual(_detected_transposition(readings), 2)

    def test_disagreement_is_not_mistaken_for_transposition(self):
        class Fake:
            def __init__(self, root):
                self.root = root
        readings = [(None, Fake(0), None, 0), (None, Fake(7), None, 2),
                    (None, Fake(5), None, 9), (None, Fake(0), None, 0)]
        self.assertEqual(_detected_transposition(readings), 0)

    def test_identical_profiles_are_zero_apart(self):
        from collections import Counter
        left = Counter({1: 10, -1: 10, 2: 5})
        self.assertEqual(profile_distance(left, Counter(left)), 0.0)
        self.assertAlmostEqual(
            profile_distance(Counter({1: 10}), Counter({-1: 10})), 1.0)

    def test_melodic_profile_counts_steps_and_leaps(self):
        notes = [Note(start=i, duration=1.0, pitch=p)
                 for i, p in enumerate([60, 62, 64, 71, 69])]
        profile = melodic_profile(notes)
        self.assertEqual(profile["moves"], 4)
        self.assertAlmostEqual(profile["stepwise"], 0.75)
        self.assertEqual(profile["leaps"], 1)      # the fifth, 64 -> 71
        self.assertEqual(profile["leap_recovered"], 1.0)   # and it turns back


class TestKeyFromTheLastChord(unittest.TestCase):
    """A cadence says what key a piece is in, if you read the right chord."""

    def cadence(self):
        # I - V - I in C, with the dominant's bass *below* the tonic's: the
        # mistake was taking the lowest note of the last bar-ish window, which
        # is the G, and calling the piece G major.
        notes = []
        for beat, (bass, chord) in enumerate([
                (48, (60, 64, 67)), (43, (59, 62, 67)), (48, (60, 64, 67))]):
            notes.append(Note(start=beat * 2.0, duration=2.0, pitch=bass))
            for pitch in chord:
                notes.append(Note(start=beat * 2.0, duration=2.0, pitch=pitch))
        return notes

    def test_the_tonic_is_the_bass_of_the_last_chord(self):
        tonic, mode, _confidence = detect_key(self.cadence())
        self.assertEqual((tonic, mode), (0, "major"))

    def test_the_old_window_reading_would_have_said_the_dominant(self):
        from middaw.corpus.analyse import _bass_pitch_class
        notes = self.cadence()
        self.assertEqual(_bass_pitch_class(notes, at_end=True), 7)     # the G


if __name__ == "__main__":
    unittest.main()
