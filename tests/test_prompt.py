import unittest

from middaw.prompt import parse_prompt, progression_is_minor
from middaw.theory import is_minor


class TestExplicitDirectives(unittest.TestCase):
    def test_key_and_mode(self):
        spec = parse_prompt("something in F# minor", seed=1)
        self.assertEqual(spec.tonic, 6)
        self.assertEqual(spec.mode, "minor")

    def test_written_out_accidentals(self):
        spec = parse_prompt("a tune in b flat major", seed=1)
        self.assertEqual(spec.tonic, 10)
        self.assertEqual(spec.mode, "major")

    def test_modal_key(self):
        spec = parse_prompt("a riff in D dorian", seed=1)
        self.assertEqual((spec.tonic, spec.mode), (2, "dorian"))

    def test_tempo(self):
        self.assertEqual(parse_prompt("lo-fi at 84 bpm", seed=1).tempo, 84)
        self.assertEqual(parse_prompt("a ballad at 68", seed=1).tempo, 68)

    def test_meter(self):
        self.assertEqual(parse_prompt("a waltz in 3/4", seed=1).meter, (3, 4))
        self.assertEqual(parse_prompt("odd meter in 7/8", seed=1).meter, (7, 8))

    def test_bar_count(self):
        self.assertEqual(parse_prompt("8 bars of piano", seed=1).bars, 8)

    def test_duration_in_seconds_becomes_bars(self):
        spec = parse_prompt("30 seconds of calm piano at 60 bpm in 4/4", seed=1)
        self.assertAlmostEqual(spec.duration_seconds, 30, delta=6)

    def test_seed_is_reproducible(self):
        a = parse_prompt("dreamy ambient piano", seed=99)
        b = parse_prompt("dreamy ambient piano", seed=99)
        self.assertEqual(a.to_dict(), b.to_dict())

    def test_seed_in_prompt_is_honoured(self):
        self.assertEqual(parse_prompt("lo-fi beat seed 4242").seed, 4242)


class TestVocabularyMatching(unittest.TestCase):
    def test_genre_and_mood(self):
        spec = parse_prompt("a sad lo-fi piano loop", seed=1)
        self.assertIn("lofi", spec.genres)
        self.assertIn("sad", spec.moods)

    def test_adjacent_phrases_both_match(self):
        spec = parse_prompt("a celtic jig", seed=1)
        self.assertEqual(spec.genres, ["celtic"])

    def test_tags_are_not_double_counted(self):
        spec = parse_prompt("lo-fi chillhop piano", seed=1)
        self.assertEqual(spec.genres, ["lofi"])

    def test_a_style_and_its_family_both_count(self):
        """Bebop is jazz, and both tags describe the music truthfully."""
        spec = parse_prompt("bebop jazz piano", seed=1)
        self.assertEqual(spec.genres, ["bebop", "jazz"])

    def test_unknown_words_are_reported(self):
        spec = parse_prompt("a lo-fi beat about kittens", seed=1)
        self.assertIn("kittens", spec.unmatched_terms)

    def test_understood_words_are_not_reported_as_unknown(self):
        spec = parse_prompt("slow sad blues in E at 70 bpm, 8 bars", seed=1)
        self.assertEqual(spec.unmatched_terms, [])

    def test_descriptors_change_density(self):
        sparse = parse_prompt("sparse ambient piano", seed=5)
        dense = parse_prompt("dense ambient piano", seed=5)
        self.assertLess(sparse.density, dense.density)


class TestCoherence(unittest.TestCase):
    def test_progression_tonality_matches_mode(self):
        prompts = ["sad lo-fi", "happy pop", "epic cinematic", "gospel piano",
                   "dark techno", "a romantic waltz", "jazz piano", "folk tune"]
        for prompt in prompts:
            for seed in range(12):
                spec = parse_prompt(prompt, seed=seed)
                self.assertEqual(
                    progression_is_minor(spec.progression), is_minor(spec.mode),
                    f"{prompt!r} seed={seed}: {spec.mode} vs {spec.progression}",
                )

    def test_values_are_always_in_range(self):
        for seed in range(40):
            spec = parse_prompt("aggressive fast dense dark techno", seed=seed)
            self.assertTrue(30 <= spec.tempo <= 240)
            self.assertTrue(0.12 <= spec.density <= 1.0)
            self.assertTrue(20 <= spec.velocity <= 120)
            self.assertTrue(1 <= spec.bars <= 128)

    def test_empty_prompt_still_produces_a_spec(self):
        spec = parse_prompt("", seed=1)
        self.assertTrue(spec.progression)
        self.assertTrue(spec.bars > 0)


if __name__ == "__main__":
    unittest.main()
