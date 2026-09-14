import unittest

from middaw.midi import bytes_to_song
from middaw.prompt import parse_prompt
from middaw.render import generate, render
from middaw.theory import scale_pitch_classes

PROMPTS = [
    "a sad lo-fi piano loop in F minor at 82 bpm",
    "epic cinematic build in 3/4, 32 bars",
    "happy playful chiptune melody",
    "dreamy ambient pad, sparse, 8 bars",
    "bebop jazz piano in Bb major",
    "a celtic jig",
    "slow blues in E",
    "minimal techno ostinato in 7/8",
    "a romantic waltz",
    "gospel piano, 12/8",
    "",
]


class TestRendering(unittest.TestCase):
    def test_every_prompt_produces_playable_midi(self):
        for prompt in PROMPTS:
            for seed in (1, 2, 3):
                with self.subTest(prompt=prompt, seed=seed):
                    result = generate(prompt, seed=seed)
                    self.assertGreater(len(result.song.notes), 8)
                    parsed = bytes_to_song(result.midi)
                    self.assertEqual(len(parsed.notes), len(result.song.notes))

    def test_notes_stay_on_an_88_key_piano(self):
        for prompt in PROMPTS:
            for seed in range(4):
                for note in generate(prompt, seed=seed).song.notes:
                    self.assertTrue(21 <= note.pitch <= 108, note.pitch)
                    self.assertTrue(1 <= note.velocity <= 127, note.velocity)
                    self.assertGreater(note.duration, 0)
                    self.assertGreaterEqual(note.start, 0)

    def test_length_matches_the_requested_bar_count(self):
        spec = parse_prompt("16 bars of calm piano in 4/4", seed=4)
        song = render(spec).song
        self.assertLessEqual(song.length_beats, spec.bars * spec.beats_per_bar + 2)
        self.assertGreater(song.length_beats, (spec.bars - 2) * spec.beats_per_bar)

    def test_same_seed_gives_identical_bytes(self):
        a = generate("dreamy ambient piano in C lydian", seed=1234)
        b = generate("dreamy ambient piano in C lydian", seed=1234)
        self.assertEqual(a.midi, b.midi)

    def test_different_seeds_give_different_music(self):
        a = generate("dreamy ambient piano in C lydian", seed=1)
        b = generate("dreamy ambient piano in C lydian", seed=2)
        self.assertNotEqual(a.midi, b.midi)

    def test_melody_stays_in_key(self):
        spec = parse_prompt("a folk melody in D dorian, 16 bars", seed=8)
        song = render(spec).song
        scale = set(scale_pitch_classes(spec.tonic, spec.mode))
        melody = [t for t in song.tracks if t.name == "Melody"][0]
        in_key = sum(1 for n in melody.notes if n.pitch % 12 in scale)
        self.assertGreaterEqual(in_key / len(melody.notes), 0.95)

    def test_roles_are_respected(self):
        spec = parse_prompt("just a bassline in E minor", seed=2)
        self.assertIn("bass", spec.roles)
        names = {t.name for t in render(spec).song.tracks}
        self.assertIn("Bass", names)

    def test_no_simultaneous_duplicate_pitches_in_a_track(self):
        for seed in range(6):
            song = generate("busy ragtime piano", seed=seed).song
            for track in song.tracks:
                seen: dict[int, float] = {}
                for note in sorted(track.notes, key=lambda n: n.start):
                    end = seen.get(note.pitch)
                    if end is not None:
                        self.assertLessEqual(end, note.start + 1e-6)
                    seen[note.pitch] = note.end


if __name__ == "__main__":
    unittest.main()


class TestAnalysisRoundTrip(unittest.TestCase):
    """What Middaw writes, Middaw's corpus labeller should read back."""

    PROMPTS = [
        "a romantic waltz in A minor", "gospel piano in Eb", "happy pop in G major",
        "folk in D mixolydian", "classical in D minor", "ragtime in C major",
        "sad lo-fi in F minor", "jazz in Bb major", "epic cinematic in C minor",
        "baroque invention in A minor", "a pop ballad in C major",
        "bossa nova in F major", "techno in F# minor", "dreamy ambient in E lydian",
        "a celtic jig in D dorian",
    ]

    def _analyse(self, prompt, seed):
        from middaw.corpus.analyse import analyse_notes
        result = generate(prompt, seed=seed)
        return result, analyse_notes(result.song.notes, result.song.tempo,
                                     result.song.meter)

    def test_tempo_and_meter_round_trip_exactly(self):
        for prompt in self.PROMPTS[:6]:
            result, derived = self._analyse(prompt, 3)
            self.assertAlmostEqual(derived["tempo"], result.spec.tempo, delta=0.5)
            self.assertEqual(derived["meter"],
                             f"{result.spec.meter[0]}/{result.spec.meter[1]}")

    def test_key_detection_is_right_most_of_the_time(self):
        # Not all of the time: a four-bar vamp that never cadences genuinely
        # has no single answer. See detect_key's docstring.
        hits = total = 0
        for prompt in self.PROMPTS:
            for seed in range(8):
                result, derived = self._analyse(prompt, seed)
                total += 1
                hits += derived["tonic"] == result.spec.tonic
        self.assertGreaterEqual(hits / total, 0.70, f"{hits}/{total}")

    def test_derived_fields_are_all_present(self):
        _result, derived = self._analyse("gospel piano in Eb", 1)
        for field in ("note_count", "bars", "tempo", "meter", "key", "density",
                      "pitch_low", "pitch_high", "syncopation", "swing",
                      "chords", "roman", "intervals", "rhythm_cells"):
            self.assertIn(field, derived)
