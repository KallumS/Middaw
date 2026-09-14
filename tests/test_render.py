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
    "a polka in 2/4",
    "motown soul at 96 bpm",
    "klezmer freygish, 16 bars",
    "boogie woogie in G",
    "a barbershop quartet in Eb",
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


class TestFormAndLength(unittest.TestCase):
    """Length comes from what the thing is called; long means sections."""

    def test_the_ladder(self):
        from middaw.form import snap_to_ladder
        self.assertEqual(snap_to_ladder(1), 4)
        self.assertEqual(snap_to_ladder(7), 8)
        self.assertEqual(snap_to_ladder(20), 16)
        self.assertEqual(snap_to_ladder(45), 32)
        self.assertEqual(snap_to_ladder(500), 64)

    def test_length_is_inferred_from_what_it_is_called(self):
        cases = [
            ("a short drum beat", 8),
            ("a lo-fi loop", 8),
            ("a jazz riff idea", 4),
            ("a verse in C major", 16),
            ("write me a full piece", 32),
            ("symphony orchestra", 64),
            ("an epic orchestral movement", 64),
        ]
        for prompt, bars in cases:
            with self.subTest(prompt=prompt):
                self.assertEqual(parse_prompt(prompt, seed=1).bars, bars)

    def test_an_explicit_bar_count_is_taken_literally(self):
        # 12 is not on the ladder, and a twelve-bar blues really is twelve bars.
        self.assertEqual(parse_prompt("12 bars of blues", seed=1).bars, 12)
        self.assertEqual(parse_prompt("6 bars of piano", seed=1).bars, 6)

    def test_short_generations_are_a_single_phrase_or_period(self):
        self.assertEqual(generate("a riff idea", seed=2).spec.form, "A")
        self.assertEqual(generate("a lo-fi loop", seed=2).spec.form, "A A'")

    def test_a_period_asks_then_answers(self):
        from middaw import cadence as cad
        result = generate("a lo-fi loop", seed=2)
        first, second = result.sections
        self.assertTrue(cad.answers(first.cadence, second.cadence),
                        f"{first.cadence} then {second.cadence}")

    def test_long_generations_get_a_contrasting_section(self):
        for prompt in ("write me a full piece", "symphony orchestra"):
            result = generate(prompt, seed=3)
            letters = {s.letter for s in result.sections}
            self.assertIn("A", letters)
            self.assertGreater(len(letters), 1,
                               f"{prompt} has no contrasting section")

    def test_sections_cover_the_piece_exactly(self):
        for prompt in ("a lo-fi loop", "a verse in C", "a full piece", "a rondo"):
            result = generate(prompt, seed=4)
            total = sum(s.bars for s in result.sections)
            self.assertEqual(total, result.spec.bars)
            starts = [s.start_bar for s in result.sections]
            self.assertEqual(starts, sorted(starts))
            expected = 0
            for section in result.sections:
                self.assertEqual(section.start_bar, expected)
                expected += section.bars

    def test_a_contrasting_section_actually_contrasts(self):
        result = generate("write me a full piece in C major", seed=6)
        a = next(s for s in result.sections if s.letter == "A")
        b = next(s for s in result.sections if s.letter == "B")
        self.assertNotEqual(a.progression, b.progression)
        self.assertGreater(b.density, a.density)

    def test_sections_that_share_a_letter_share_their_harmony(self):
        # Same music, different endings: a refrain that stops on the dominant
        # and the same refrain that closes differ only in their last chords.
        result = generate("symphony orchestra in D minor", seed=8)
        by_letter = {}
        for section in result.sections:
            by_letter.setdefault(section.letter, []).append(section)
        for letter, sections in by_letter.items():
            first = sections[0]
            for section in sections[1:]:
                self.assertEqual(section.progression[:-2], first.progression[:-2],
                                 f"{letter}: the openings should match")
                if section.cadence == first.cadence:
                    self.assertEqual(section.progression, first.progression, letter)

    def test_a_long_piece_is_not_one_loop_repeated(self):
        # The length word sets a target; the form sets the real length, because
        # a five-section rondo is five sections long whatever was asked for.
        result = generate("symphony orchestra", seed=9)
        self.assertGreaterEqual(result.spec.bars, 48)
        self.assertGreaterEqual(len(result.sections), 4)
        melody = [t for t in result.song.tracks if t.name == "Melody"][0]
        beats_per_bar = result.spec.beats_per_bar
        first = [round(n.start % (8 * beats_per_bar), 2) for n in melody.notes
                 if n.start < 8 * beats_per_bar]
        bridge = [round(n.start % (8 * beats_per_bar), 2) for n in melody.notes
                  if 16 * beats_per_bar <= n.start < 24 * beats_per_bar]
        self.assertNotEqual(first, bridge)

    def test_long_pieces_still_produce_valid_midi(self):
        from middaw.midi import bytes_to_song
        for prompt in ("symphony orchestra", "a full piece", "a verse"):
            result = generate(prompt, seed=5)
            parsed = bytes_to_song(result.midi)
            self.assertEqual(len(parsed.notes), len(result.song.notes))
            for note in result.song.notes:
                self.assertTrue(21 <= note.pitch <= 108)
