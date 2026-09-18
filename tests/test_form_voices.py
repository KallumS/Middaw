"""Cadences, forms and the voices other than the melody."""

import random
import unittest

from middaw import cadence as cad
from middaw.form import FORMS, OPEN_ROLES, plan_cadences
from middaw.functional import closing_chords, generate_progression, recadence
from middaw.prompt import parse_prompt
from middaw.render import generate
from middaw.theory import parse_roman
from middaw.voices import _makes_parallel


class TestCadences(unittest.TestCase):
    def test_the_five_cadences_are_classified(self):
        self.assertEqual(set(cad.CONCLUSIVE), {cad.PAC, cad.IAC, cad.PC})
        self.assertEqual(set(cad.INCONCLUSIVE), {cad.DC, cad.HC})
        self.assertTrue(cad.answers(cad.HC, cad.PAC))
        self.assertTrue(cad.answers(cad.IAC, cad.PAC))
        self.assertFalse(cad.answers(cad.PAC, cad.HC))

    def test_each_cadence_spells_the_right_chords(self):
        cases = {
            cad.PAC: ([7, 0], "V7"),      # V7 - I
            cad.IAC: ([7, 0], None),      # V - I
            cad.PC:  ([5, 0], None),      # IV - I
            cad.DC:  ([7, 9], "V7"),      # V7 - vi
            cad.HC:  ([7], None),         # ends on V
        }
        for kind, (roots, first_symbol) in cases.items():
            chords = closing_chords(0, "major", kind, sevenths=False)
            with self.subTest(cadence=kind):
                self.assertEqual([c.root for c in chords], roots)
                if first_symbol:
                    self.assertEqual(chords[0].symbol, first_symbol)

    def test_a_progression_ends_on_the_cadence_it_was_asked_for(self):
        for mode in ("major", "minor", "dorian", "mixolydian"):
            for kind in cad.CADENCES:
                for seed in range(8):
                    progression = generate_progression(
                        0, mode, 4, 0.5, 0.5, random.Random(seed), cadence=kind)
                    expected = closing_chords(0, mode, kind, sevenths=False)
                    got = [parse_roman(c.symbol, 0, mode).root
                           for c in progression[-len(expected):]]
                    with self.subTest(mode=mode, cadence=kind, seed=seed):
                        self.assertEqual(got, [c.root for c in expected])

    def test_conclusive_cadences_end_on_the_tonic(self):
        for kind in cad.CONCLUSIVE:
            progression = generate_progression(0, "major", 4, 0.5, 0.5,
                                               random.Random(1), cadence=kind)
            self.assertEqual(parse_roman(progression[-1].symbol, 0, "major").root, 0)

    def test_a_half_cadence_does_not(self):
        progression = generate_progression(0, "major", 4, 0.5, 0.5,
                                           random.Random(1), cadence=cad.HC)
        self.assertEqual(parse_roman(progression[-1].symbol, 0, "major").root, 7)

    def test_modal_keys_keep_their_own_dominant(self):
        # Raising dorian's flat seventh to make a leading tone turns it into
        # minor, so a dorian cadence uses the mode's own minor v.
        chords = closing_chords(2, "dorian", cad.PAC, sevenths=False)
        self.assertTrue(chords[0].symbol[:1].islower(), chords[0].symbol)
        chords = closing_chords(2, "minor", cad.PAC, sevenths=False)
        self.assertEqual(chords[0].symbol, "V7")

    def test_recadencing_keeps_the_opening(self):
        symbols = ["I", "vi", "ii", "V"]
        labels = list(symbols)
        new, _ = recadence(symbols, labels, 0, "major", cad.PAC)
        self.assertEqual(new[:2], symbols[:2])
        self.assertEqual(parse_roman(new[-1], 0, "major").root, 0)


class TestFormPlan(unittest.TestCase):
    def test_every_form_ends_conclusively(self):
        for name, layout in FORMS.items():
            for seed in range(10):
                plan = plan_cadences(layout, random.Random(seed))
                with self.subTest(form=name, seed=seed):
                    self.assertEqual(len(plan), len(layout))
                    self.assertTrue(cad.is_conclusive(plan[-1]), plan)

    def test_sections_that_lead_somewhere_stop_on_the_dominant(self):
        for name, layout in FORMS.items():
            plan = plan_cadences(layout, random.Random(2))
            for (label, role), kind in list(zip(layout, plan))[:-1]:
                if any(open_role in role for open_role in OPEN_ROLES):
                    with self.subTest(form=name, section=label):
                        self.assertEqual(kind, cad.HC)

    def test_named_forms_are_honoured(self):
        cases = {"a fugue": "fugue", "write a rondo": "rondo",
                 "ternary form": "ternary", "a medley": "medley",
                 "through composed": "through_composed", "strophic song": "strophic",
                 "binary form": "binary", "aaba standard": "aaba",
                 "sonata": "sonata", "abacaba": "rondo_seven"}
        for prompt, form in cases.items():
            with self.subTest(prompt=prompt):
                self.assertEqual(generate(prompt, seed=3).spec.form_name, form)

    def test_a_rondo_brings_its_refrain_back(self):
        result = generate("write a rondo in C major", seed=4)
        labels = [s.label for s in result.sections]
        self.assertEqual(labels, ["A", "B", "A'", "C", "A''"])
        self.assertEqual([s.role for s in result.sections][1], "first episode")

    def test_a_fugue_answers_a_fifth_above(self):
        result = generate("a fugue in D minor", seed=4)
        answer = next(s for s in result.sections if "answer" in s.role)
        self.assertEqual(answer.transpose, 7)
        self.assertEqual(result.sections[0].role, "subject")

    def test_naming_a_form_names_an_era(self):
        self.assertIn("baroque", generate("a fugue", seed=1).spec.genres)
        self.assertIn("classical", generate("a sonata", seed=1).spec.genres)

    def test_sections_cover_the_piece(self):
        for prompt in ("a rondo", "a fugue", "a medley", "sonata", "ternary form"):
            result = generate(prompt, seed=5)
            self.assertEqual(sum(s.bars for s in result.sections), result.spec.bars)


class TestVoices(unittest.TestCase):
    def test_asking_for_a_figure_sets_the_harmony_treatment(self):
        """An ostinato is not a fifth track, it is how the harmony is played."""
        result = generate("an ostinato in C minor", seed=2)
        self.assertEqual(result.spec.harmony, "ostinato")
        harmony = [t for t in result.song.tracks if t.role == "harmony"][0]
        self.assertEqual(harmony.detail, "ostinato")
        self.assertTrue(harmony.notes)
        silent = {t.role for t in result.song.tracks if not t.notes}
        self.assertIn("melody", silent)

    def test_asking_for_a_countermelody_gets_a_melody_too(self):
        spec = parse_prompt("a countermelody", seed=1)
        self.assertEqual(spec.voices[:2], ["melody", "countermelody"])

    def test_one_line_alone_still_gets_a_foundation(self):
        self.assertIn("bass", parse_prompt("just a melody", seed=1).voices)
        self.assertEqual(parse_prompt("just a bassline", seed=1).voices, ["bass"])

    def test_a_prompt_that_names_nothing_gets_all_four_parts(self):
        """Four voices, and a kit when the style has one."""
        self.assertEqual(parse_prompt("a pop tune in G", seed=1).voices,
                         ["melody", "countermelody", "harmony", "bass", "drums"])
        self.assertEqual(parse_prompt("a hymn in F", seed=1).voices,
                         ["melody", "countermelody", "harmony", "bass"])

    def test_styles_bring_their_own_harmony_treatment(self):
        self.assertEqual(parse_prompt("minimal piano", seed=1).harmony, "ostinato")
        self.assertEqual(parse_prompt("a trance lead", seed=1).harmony, "arpeggio")
        self.assertEqual(parse_prompt("a jazz tune", seed=1).harmony, "chords")

    def test_the_countermelody_stays_under_the_melody(self):
        result = generate("baroque invention in C major", seed=3)
        tracks = {t.name: t for t in result.song.tracks}
        melody, counter = tracks["Melody"], tracks["Countermelody"]
        above = sum(1 for c in counter.notes for m in melody.notes
                    if m.start <= c.start < m.end and c.pitch > m.pitch)
        self.assertLessEqual(above / max(1, len(counter.notes)), 0.05)

    def test_the_countermelody_is_a_real_second_voice(self):
        result = generate("baroque invention in C major", seed=3)
        tracks = {t.name: t for t in result.song.tracks}
        ratio = len(tracks["Countermelody"].notes) / len(tracks["Melody"].notes)
        self.assertGreater(ratio, 0.3, "the second line should not be a token")

    def test_parallel_perfect_intervals_are_detected(self):
        # Two voices a fifth apart both rising a step: parallel fifths.
        self.assertTrue(_makes_parallel(60, 62, 67, 69))
        # Contrary motion is fine.
        self.assertFalse(_makes_parallel(60, 58, 67, 69))
        # A third moving to a third is fine.
        self.assertFalse(_makes_parallel(60, 62, 64, 66))

    def test_an_ostinato_repeats_one_figure(self):
        # Tested before humanisation, which nudges notes off the grid: the
        # invariant is that one figure is restated over every chord.
        from middaw.render import build_chord_spans, _chords_by_bar
        from middaw.voices import generate_ostinato, make_ostinato_figure
        spec = parse_prompt("minimal techno ostinato in A minor, 8 bars", seed=5)
        rng = random.Random(5)
        spans = build_chord_spans(spec, rng)
        figure = make_ostinato_figure(spec, random.Random(11))
        notes = generate_ostinato(spec, spans, rng, figure)

        by_span = {}
        for start, length, _chord in spans:
            by_span[start] = sorted(
                round(n.start - start, 4) for n in notes
                if start <= n.start < start + length)
        shapes = list(by_span.values())
        for shape in shapes[1:]:
            self.assertEqual(shape, shapes[0])
        self.assertGreater(len(shapes[0]), 1)

    def test_every_voice_combination_produces_playable_midi(self):
        from middaw.midi import bytes_to_song
        prompts = ["a fugue", "ostinato and arpeggio", "just a bassline",
                   "a melody with countermelody", "ambient pad", "minimal piano"]
        for prompt in prompts:
            with self.subTest(prompt=prompt):
                result = generate(prompt, seed=6)
                self.assertTrue(result.song.tracks)
                parsed = bytes_to_song(result.midi)
                self.assertEqual(len(parsed.notes), len(result.song.notes))


if __name__ == "__main__":
    unittest.main()
