"""The kit: the patterns are what they claim, and the feel is what was measured."""

import collections
import random
import unittest

from middaw.chance import Chances
from middaw.drums import (ACCENT, DRUM_CHANNEL, GHOST, NORMAL, REST,
                          generate_drums, grid_of, kit_note, load_kit,
                          pattern_for, patterns, fills)
from middaw.prompt import parse_prompt, wants_drums
from middaw.render import render
from middaw.song import DRUM_CHANNEL as SONG_DRUM_CHANNEL

STROKES = (ACCENT, NORMAL, GHOST, REST)


class TestThePatternLibrary(unittest.TestCase):
    def test_every_line_is_exactly_one_bar(self):
        for group in (patterns(), fills()):
            for name, pattern in group.items():
                for instrument, line in pattern.lines.items():
                    with self.subTest(pattern=name, instrument=instrument):
                        self.assertEqual(len(line), pattern.steps)

    def test_every_stroke_is_a_stroke(self):
        for group in (patterns(), fills()):
            for name, pattern in group.items():
                for instrument, line in pattern.lines.items():
                    for stroke in line:
                        with self.subTest(pattern=name, stroke=stroke):
                            self.assertIn(stroke, STROKES)

    def test_every_instrument_is_in_the_kit(self):
        for group in (patterns(), fills()):
            for name, pattern in group.items():
                for instrument in pattern.lines:
                    with self.subTest(pattern=name, instrument=instrument):
                        self.assertIsNotNone(kit_note(instrument))

    def test_every_pattern_has_something_on_the_downbeat(self):
        """A bar that starts with nothing is a fill, not a beat."""
        for name, pattern in patterns().items():
            with self.subTest(pattern=name):
                first = [line[0] for line in pattern.lines.values()]
                self.assertTrue(any(stroke != REST for stroke in first),
                                f"{name} starts on silence")

    def test_every_style_names_a_pattern_that_exists(self):
        library = patterns()
        for genre, weights in load_kit()["genres"].items():
            for name in weights:
                with self.subTest(genre=genre):
                    self.assertIn(name, library)

    def test_the_named_beats_are_the_beats_they_are_named_for(self):
        """The two everybody knows, checked against the definition."""
        library = patterns()
        backbeat = library["backbeat"]
        self.assertEqual(backbeat.lines["snare"][4], ACCENT)    # beat two
        self.assertEqual(backbeat.lines["snare"][12], ACCENT)   # beat four
        self.assertEqual(backbeat.lines["kick"][0], ACCENT)     # beat one

        four = library["four_on_the_floor"]
        self.assertEqual([four.lines["kick"][s] for s in (0, 4, 8, 12)],
                         [ACCENT] * 4)

        one_drop = library["one_drop"]
        self.assertEqual(one_drop.lines["kick"][0], REST)       # not on one
        self.assertEqual(one_drop.lines["kick"][8], ACCENT)     # on three


class TestChoosingABeat(unittest.TestCase):
    def test_a_style_gets_its_own_beat(self):
        for prompt, expected in (("minimal techno", "four_on_the_floor"),
                                 ("one drop reggae", "one_drop"),
                                 ("boom bap in F minor", "boom_bap"),
                                 ("a bossa nova", "bossa")):
            spec = parse_prompt(prompt + ", 4/4", seed=1)
            chosen = pattern_for(spec, random.Random(1))
            with self.subTest(prompt=prompt):
                self.assertEqual(chosen.name, expected)

    def test_a_meter_with_no_beat_written_for_it_gets_silence_not_a_guess(self):
        spec = parse_prompt("a prog rock piece in 7/8", seed=1)
        self.assertEqual(spec.meter, (7, 8))
        self.assertIsNone(pattern_for(spec, random.Random(1)))
        self.assertEqual(generate_drums(spec, 4, random.Random(1)), [])

    def test_a_three_four_piece_gets_a_three_four_beat(self):
        spec = parse_prompt("a waltz in D", seed=1)
        chosen = pattern_for(spec, random.Random(2))
        self.assertIn("3/4", chosen.meters)


class TestWhoGetsADrummer(unittest.TestCase):
    def test_styles_that_have_one(self):
        for prompt in ("a pop tune in G", "minimal techno", "one drop reggae"):
            self.assertIn("drums", parse_prompt(prompt, seed=1).voices)

    def test_styles_that_do_not(self):
        for prompt in ("a hymn in F", "baroque invention in C major",
                       "a renaissance madrigal"):
            self.assertNotIn("drums", parse_prompt(prompt, seed=1).voices)

    def test_asking_and_refusing_both_win(self):
        self.assertIn("drums", parse_prompt("a hymn with drums", seed=1).voices)
        for refusal in ("a pop tune, no drums", "rock without drums",
                        "a drumless pop song"):
            self.assertNotIn("drums", parse_prompt(refusal, seed=1).voices,
                             refusal)


class TestThePlaying(unittest.TestCase):
    def _drums(self, prompt="a rock song in E, 16 bars", seed=1):
        result = render(parse_prompt(prompt, seed=seed))
        return [t for t in result.song.tracks if t.role == "drums"][0]

    def test_the_kit_plays_on_channel_ten(self):
        self.assertEqual(self._drums().channel, DRUM_CHANNEL)
        self.assertEqual(DRUM_CHANNEL, SONG_DRUM_CHANNEL)

    def test_a_beat_lands_where_the_pattern_says(self):
        spec = parse_prompt("minimal techno, 4/4, 8 bars", seed=4)
        spec.humanize = 0.0
        notes = generate_drums(spec, 8, random.Random(1),
                               pattern=patterns()["four_on_the_floor"])
        grid = grid_of(notes, spec.beats_per_bar)
        self.assertEqual(sorted(grid["kick"]), [0, 4, 8, 12])
        self.assertEqual(sorted(grid["clap"]), [4, 12])

    def test_a_hit_off_the_beat_is_quieter_than_one_on_it(self):
        """Measured at 0.78 of it across 470,000 real hits."""
        spec = parse_prompt("a rock song in E, 4/4", seed=2)
        spec.humanize = 0.0
        notes = generate_drums(spec, 8, random.Random(2),
                               pattern=patterns()["backbeat"])
        hats = [n for n in notes if n.pitch == kit_note("hat")]
        on = [n.velocity for n in hats if abs(n.start % 1.0) < 1e-6]
        off = [n.velocity for n in hats if abs(n.start % 1.0) > 1e-6]
        self.assertTrue(on and off)
        self.assertLess(sum(off) / len(off), sum(on) / len(on))

    def test_ghost_strokes_answer_their_dial(self):
        spec = parse_prompt("funk in E minor, 4/4", seed=3)
        spec.humanize = 0.0

        def ghosts(chance: float) -> int:
            spec.chances = Chances(ghost_note=chance)
            notes = generate_drums(spec, 24, random.Random(5),
                                   pattern=patterns()["funk_sixteenths"])
            snare = kit_note("snare")
            return sum(1 for n in notes if n.pitch == snare)

        self.assertGreater(ghosts(1.0), ghosts(0.0))

    def _bars(self, notes, beats_per_bar):
        """What each bar played, as a set of (position, instrument)."""
        bars = collections.defaultdict(set)
        for note in notes:
            bar = int(note.start // beats_per_bar)
            position = round((note.start % beats_per_bar) * 4)
            bars[bar].add((position, note.pitch))
        return bars

    def test_a_fill_arrives_at_the_end_of_a_phrase(self):
        spec = parse_prompt("a rock song in E, 4/4", seed=6)
        spec.humanize = 0.0
        for seed in range(6):
            notes = generate_drums(spec, 8, random.Random(seed),
                                   pattern=patterns()["backbeat"], phrase=4)
            bars = self._bars(notes, spec.beats_per_bar)
            plain = bars[0]
            # Bar four ends the first phrase; bars one to three do not.
            self.assertEqual(bars[1], plain, "a plain bar changed")
            self.assertEqual(bars[2], plain, "a plain bar changed")
            if bars[3] != plain:
                return                        # the fill landed where it should
        self.fail("no fill was played in six tries at the default chance")

    def test_no_fill_over_the_last_bar(self):
        """The piece ends on the beat, not on a roll into nothing."""
        spec = parse_prompt("a rock song in E, 4/4", seed=8)
        spec.humanize = 0.0
        spec.chances = Chances(drum_fill=1.0)
        notes = generate_drums(spec, 4, random.Random(9),
                               pattern=patterns()["backbeat"], phrase=4)
        bars = self._bars(notes, spec.beats_per_bar)
        self.assertEqual(bars[3], bars[0])

    def test_the_kit_never_reaches_the_key_detector(self):
        """Note 36 on channel 10 is a kick, not a C. It used to be counted."""
        result = render(parse_prompt("minimal techno in F# minor", seed=3))
        self.assertLess(len(result.song.pitched_notes), len(result.song.notes))
        drums = {id(n) for t in result.song.tracks if t.role == "drums"
                 for n in t.notes}
        for note in result.song.pitched_notes:
            self.assertNotIn(id(note), drums)

    def test_velocities_and_pitches_stay_legal(self):
        for prompt in ("a rock song in E", "minimal techno", "a bossa nova",
                       "bebop jazz piano", "one drop reggae", "a waltz in D"):
            for note in self._drums(prompt, seed=2).notes:
                self.assertTrue(1 <= note.velocity <= 127)
                self.assertTrue(0 <= note.pitch <= 127)
                self.assertGreater(note.duration, 0)
                self.assertGreaterEqual(note.start, 0)


if __name__ == "__main__":
    unittest.main()
