import json
import tempfile
import unittest
from datetime import date
from pathlib import Path

from middaw.corpus.analyse import analyse_file, analyse_notes, detect_key
from middaw.corpus.cli import main as corpus_main
from middaw.corpus.schema import Entry, validate_entry
from middaw.corpus.stats import CorpusPriors, load_corpus_priors
from middaw.melody import DEFAULT_INTERVALS
from middaw.render import generate
from middaw.vocab import load_vocabulary


def _good_provenance(**overrides):
    data = {
        "source": "Mutopia Project",
        "source_url": "https://www.mutopiaproject.org/",
        "license": "CC0-1.0",
        "composer": "Johann Sebastian Bach",
        "composer_died": 1750,
        "sequencer": "Mutopia contributor",
        "rights_basis": "public-domain composition, CC0 engraving",
        "verified_by": "kallum",
        "verified_on": "2026-09-14",
    }
    data.update(overrides)
    return data


class TestSchema(unittest.TestCase):
    def setUp(self):
        self.vocab = load_vocabulary()

    def test_a_complete_entry_validates(self):
        entry = Entry(id="mutopia-bwv846", file="bwv846.mid",
                      provenance=_good_provenance(),
                      tags={"genres": ["baroque"], "moods": ["calm"]})
        self.assertEqual(validate_entry(entry, self.vocab), [])

    def test_missing_provenance_is_rejected(self):
        entry = Entry(id="mystery-file", file="x.mid")
        problems = validate_entry(entry, self.vocab)
        self.assertTrue(any("provenance.license" in p for p in problems))
        self.assertTrue(any("provenance.source" in p for p in problems))

    def test_a_midi_file_needs_its_own_sequencer_credited(self):
        provenance = _good_provenance()
        provenance.pop("sequencer")
        problems = validate_entry(
            Entry(id="x-y", file="x.mid", provenance=provenance), self.vocab)
        self.assertTrue(any("sequencer" in p for p in problems))

    def test_public_domain_claims_need_a_death_date(self):
        provenance = _good_provenance(license="PD")
        provenance.pop("composer_died")
        problems = validate_entry(
            Entry(id="x-y", file="x.mid", provenance=provenance), self.vocab)
        self.assertTrue(any("composer_died" in p for p in problems))

    def test_free_text_tags_are_rejected(self):
        entry = Entry(id="x-y", file="x.mid", provenance=_good_provenance(),
                      tags={"moods": ["chill vibes"]})
        problems = validate_entry(entry, self.vocab)
        self.assertTrue(any("chill vibes" in p for p in problems))

    def test_unknown_licences_are_rejected_rather_than_assumed(self):
        entry = Entry(id="x-y", file="x.mid",
                      provenance=_good_provenance(license="Whatever-1.0"))
        problems = validate_entry(entry, self.vocab)
        self.assertTrue(any("not in the known set" in p for p in problems))

    def test_non_commercial_licences_are_not_commercial_ok(self):
        entry = Entry(id="x-y", file="x.mid",
                      provenance=_good_provenance(license="CC-BY-NC-SA-4.0"))
        self.assertEqual(validate_entry(entry, self.vocab), [])
        self.assertFalse(entry.commercial_ok)


class TestAnalysis(unittest.TestCase):
    def test_key_detection_on_a_plain_cadence(self):
        result = generate("classical piano in C major, 8 bars", seed=4)
        tonic, mode, confidence = detect_key(result.song.notes)
        self.assertEqual(tonic, 0)
        self.assertEqual(mode, "major")
        self.assertGreater(confidence, 0.8)

    def test_empty_input(self):
        self.assertEqual(analyse_notes([], 120, (4, 4)), {"note_count": 0})
        self.assertEqual(detect_key([]), (0, "major", 0.0))

    def test_analysing_a_written_file(self):
        result = generate("gospel piano in Eb, 8 bars", seed=1)
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "x.mid"
            path.write_bytes(result.midi)
            derived = analyse_file(path)
        self.assertEqual(derived["meter"],
                         f"{result.spec.meter[0]}/{result.spec.meter[1]}")
        self.assertGreater(derived["note_count"], 0)
        self.assertTrue(derived["chords"])


class TestPriors(unittest.TestCase):
    def test_an_empty_corpus_changes_nothing(self):
        priors = CorpusPriors()
        self.assertEqual(priors.intervals_for(["lofi"], DEFAULT_INTERVALS),
                         dict(DEFAULT_INTERVALS))
        self.assertEqual(priors.progressions_for(["lofi"]), [])
        self.assertEqual(priors.rhythm_bias_for(["lofi"]), {})

    def test_restricted_licences_are_kept_out_of_the_default_split(self):
        entry = Entry(id="nc-file", file="x.mid",
                      provenance=_good_provenance(license="CC-BY-NC-SA-4.0"),
                      derived={"intervals": {"1": 10}, "roman": ["i", "iv", "V7", "i"]},
                      tags={"genres": ["jazz"]})
        priors = CorpusPriors()
        priors.add(entry, commercial_only=True)
        self.assertEqual(priors.entries, 0)
        priors.add(entry, commercial_only=False)
        self.assertEqual(priors.entries, 1)

    def test_a_corpus_moves_the_interval_distribution(self):
        priors = CorpusPriors()
        for index in range(50):
            priors.add(Entry(
                id=f"leaps-{index:03d}", file=f"{index}.mid",
                provenance=_good_provenance(),
                derived={"intervals": {"4": 200, "-4": 200},
                         "roman": ["i", "iv", "V7", "i"] * 2,
                         "rhythm_cells": {"0.5,0.5": 40}, "tempo": 90},
                tags={"genres": ["lofi"]},
            ))
        blended = priors.intervals_for(["lofi"], DEFAULT_INTERVALS)
        self.assertGreater(blended[4], blended[1])       # the corpus's leaps win
        self.assertIn(1, blended)                        # but the default survives
        self.assertTrue(priors.progressions_for(["lofi"]))
        self.assertTrue(priors.rhythm_bias_for(["lofi"]))
        self.assertEqual(len(priors.sources_for(["lofi"])), 12)

    def test_influence_grows_with_the_amount_of_data(self):
        def influence(count):
            priors = CorpusPriors()
            for index in range(count):
                priors.add(Entry(
                    id=f"e-{index:03d}", file="x.mid", provenance=_good_provenance(),
                    derived={"intervals": {"4": 10}}, tags={"genres": ["pop"]}))
            return priors.intervals_for(["pop"], DEFAULT_INTERVALS)[4]

        self.assertLess(influence(1), influence(10))
        self.assertLess(influence(10), influence(200))


class TestCli(unittest.TestCase):
    def test_ingest_validate_and_stats_on_a_fresh_directory(self):
        with tempfile.TemporaryDirectory() as tmp:
            directory = Path(tmp)
            (directory / "demo.mid").write_bytes(
                generate("a folk tune in G major, 8 bars", seed=2).midi)

            self.assertEqual(corpus_main(["-d", str(directory), "ingest"]), 0)
            manifest = json.loads((directory / "manifest.json").read_text())
            self.assertEqual(len(manifest["entries"]), 1)
            entry = manifest["entries"][0]
            self.assertEqual(entry["id"], "demo")
            self.assertGreater(entry["derived"]["note_count"], 0)
            self.assertIn("sha256", entry["provenance"])

            # A freshly ingested file has no provenance, so it must not validate.
            self.assertEqual(corpus_main(["-d", str(directory), "validate",
                                          "--strict"]), 1)
            self.assertEqual(load_corpus_priors(directory).entries, 0)

            entry["provenance"].update(_good_provenance(
                license="owned-original", composer="Kallum",
                verified_on=date.today().isoformat()))
            entry["tags"] = {"genres": ["folk"]}
            (directory / "manifest.json").write_text(json.dumps(manifest))

            self.assertEqual(corpus_main(["-d", str(directory), "validate",
                                          "--strict"]), 0)
            self.assertEqual(load_corpus_priors(directory).entries, 1)

    def test_ingest_is_idempotent_and_keeps_hand_written_fields(self):
        with tempfile.TemporaryDirectory() as tmp:
            directory = Path(tmp)
            (directory / "demo.mid").write_bytes(generate("pop, 8 bars", seed=2).midi)
            corpus_main(["-d", str(directory), "ingest"])
            manifest = json.loads((directory / "manifest.json").read_text())
            manifest["entries"][0]["tags"] = {"genres": ["pop"]}
            manifest["entries"][0]["provenance"]["source"] = "written for Middaw"
            (directory / "manifest.json").write_text(json.dumps(manifest))

            corpus_main(["-d", str(directory), "ingest"])
            again = json.loads((directory / "manifest.json").read_text())
            self.assertEqual(len(again["entries"]), 1)
            self.assertEqual(again["entries"][0]["tags"], {"genres": ["pop"]})
            self.assertEqual(again["entries"][0]["provenance"]["source"],
                             "written for Middaw")


if __name__ == "__main__":
    unittest.main()
