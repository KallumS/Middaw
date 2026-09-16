"""The vocabulary is data, so it is checked like data.

Every genre in `data/vocab/tags.json` has to be reachable from a prompt, has
to name modes, meters, figures and chords the generator actually has, and has
to render. A style whose progressions do not fit its own modes silently falls
back to the mode default, so that is checked too rather than assumed.
"""

import unittest

from middaw.accompaniment import PATTERNS
from middaw.form import FORMS, GENRE_FORMS, PLAGAL_GENRES
from middaw.parts import PARTS, TREATMENTS, VOICE_PARTS
from middaw.prompt import (GENRE_TREATMENT, parse_prompt, progression_fit,
                           progression_is_minor)
from middaw.render import render
from middaw.spec import MusicSpec
from middaw.theory import SCALES, parse_roman
from middaw.vocab import axis_of, load_vocabulary

VOCAB = load_vocabulary()

REQUIRED = ("label", "synonyms", "tempo", "modes", "meters", "progressions",
            "patterns", "density", "swing", "extensions", "register",
            "velocity", "chromaticism", "functional", "ornament")


class TestGenreEntries(unittest.TestCase):
    def test_every_genre_is_completely_described(self):
        for tag, entry in VOCAB.genres.items():
            with self.subTest(genre=tag):
                for key in REQUIRED:
                    self.assertIn(key, entry)
                low, high = entry["tempo"]
                self.assertLess(low, high)
                self.assertTrue(30 <= low and high <= 300, entry["tempo"])
                self.assertTrue(0.0 <= entry["density"] <= 1.0)
                self.assertTrue(0.0 <= entry["swing"] <= 0.5)
                self.assertTrue(0.0 <= entry["ornament"] <= 1.0)
                self.assertTrue(0.0 <= entry["chromaticism"] <= 1.0)
                self.assertTrue(0.0 <= entry["functional"] <= 1.0)
                self.assertTrue(20 <= entry["velocity"] <= 120)

    def test_modes_meters_and_figures_all_exist(self):
        for tag, entry in VOCAB.genres.items():
            with self.subTest(genre=tag):
                self.assertTrue(entry["modes"])
                for mode in entry["modes"]:
                    self.assertIn(mode, SCALES)
                for meter in entry["meters"]:
                    top, bottom = meter.split("/")
                    self.assertGreater(int(top), 0)
                    self.assertIn(int(bottom), (2, 4, 8, 16))
                for pattern in entry["patterns"]:
                    self.assertIn(pattern, PATTERNS)

    def test_every_chord_symbol_parses(self):
        for tag, entry in VOCAB.genres.items():
            for progression in entry["progressions"]:
                for symbol in progression["c"]:
                    with self.subTest(genre=tag, symbol=symbol):
                        parse_roman(symbol, 0, "major")

    def test_a_styles_progressions_fit_the_modes_it_names(self):
        """A progression that does not fit is never chosen, so it is dead data.

        Falling back to the mode's own default is deliberate for the handful
        of styles below - a locrian techno loop has no stock progression - but
        it should be a decision, not an accident.
        """
        allowed_fallbacks = {
            ("boogie_woogie", "blues"), ("rockabilly", "blues"),
            ("cinematic", "major"), ("house", "dorian"), ("pop", "minor"),
            ("minimal", "mixolydian"), ("techno", "locrian"),
            ("metal", "locrian"), ("impressionist", "whole_tone"),
            ("new_age", "dorian"), ("synthwave", "major"),
            ("boogie_woogie", "major"),
        }
        for tag, entry in VOCAB.genres.items():
            for mode in entry["modes"]:
                if (tag, mode) in allowed_fallbacks:
                    continue
                spec = MusicSpec(tonic=0, mode=mode)
                usable = [p["c"] for p in entry["progressions"]
                          if progression_is_minor(tuple(p["c"])) == spec.is_minor
                          and progression_fit(tuple(p["c"]), spec) >= 0.85]
                with self.subTest(genre=tag, mode=mode):
                    self.assertTrue(usable, f"{tag} names {mode} but no listed "
                                            f"progression fits it")

    def test_every_genre_can_be_asked_for_and_renders(self):
        for tag, entry in VOCAB.genres.items():
            with self.subTest(genre=tag):
                spec = parse_prompt(f"{entry['label']} piece", seed=3)
                self.assertIn(tag, spec.genres)
                song = render(spec).song
                self.assertEqual([t.role for t in song.tracks], list(PARTS))
                self.assertGreater(len(song.notes), 8)
                for track in song.tracks:
                    if track.role == "drums":
                        continue      # a hymn has no drummer; see parts.py
                    self.assertTrue(track.notes, f"{tag} left {track.role} silent")
                for note in song.notes:
                    self.assertTrue(21 <= note.pitch <= 108)


class TestPhraseIndex(unittest.TestCase):
    def test_a_phrase_describes_each_axis_only_once(self):
        """Loading enforces it; this says so out loud."""
        claims: dict[tuple[str, str], list[str]] = {}
        for phrase, tags in VOCAB._phrases:
            for kind, tag in tags:
                claims.setdefault((phrase, axis_of(kind)), []).append(f"{kind} {tag}")
        for (phrase, axis), owners in claims.items():
            with self.subTest(phrase=phrase, axis=axis):
                self.assertEqual(len(owners), 1, f"{phrase!r}: {owners}")

    def test_one_word_can_carry_a_style_and_a_length(self):
        spec = parse_prompt("a soundtrack", seed=1)
        self.assertIn("cinematic", spec.genres)
        self.assertIn("work", spec.scales)

    def test_a_longer_phrase_does_not_swallow_another_axis(self):
        """"waltz piece" is a length; the waltz inside it is still a waltz."""
        spec = parse_prompt("a waltz piece", seed=1)
        self.assertEqual(spec.genres, ["waltz"])
        self.assertIn("piece", spec.scales)


class TestParts(unittest.TestCase):
    def test_every_voice_word_belongs_to_a_part(self):
        """A voice word a prompt can say has to land on one of the parts."""
        for tag in VOCAB.voices:
            self.assertIn(tag, VOICE_PARTS)
            self.assertIn(VOICE_PARTS[tag], PARTS)

    def test_a_treatment_word_is_the_harmony_part(self):
        for treatment in TREATMENTS:
            self.assertEqual(VOICE_PARTS[treatment], "harmony")


class TestGenreTables(unittest.TestCase):
    def test_form_and_voice_tables_name_real_tags(self):
        for tag in GENRE_FORMS:
            self.assertIn(tag, VOCAB.genres)
        for tag, forms in GENRE_FORMS.items():
            for form in forms:
                self.assertIn(form, FORMS, f"{tag} asks for {form}")
        for tag, treatment in GENRE_TREATMENT.items():
            self.assertIn(tag, VOCAB.genres)
            self.assertIn(treatment, TREATMENTS)
        for tag in PLAGAL_GENRES:
            self.assertIn(tag, VOCAB.genres)


if __name__ == "__main__":
    unittest.main()
