# How to label the dataset

This is the design decision that everything else rests on. Get it wrong and
the corpus becomes unqueryable within a few thousand files, which is the point
at which it stops being a dataset and becomes a folder.

## The one rule

**A label is either a fact about the file, or a word from a fixed list.
Never free text.**

Free-text tags feel flexible for the first week. By file 500 you have `chill`,
`chilled`, `chill vibes`, `chillout` and `Chill`, and no query returns the
right set. `middaw.corpus.schema.validate_entry` rejects any tag that is not
an id in `data/vocab/tags.json`, and it rejects it at ingest, when fixing it
costs nothing.

## Three tiers

### Tier 1 — provenance. Required, human-entered, never guessed.

Where the file came from and why you may use it. `source`, `license`,
`rights_basis`, `sequencer`, `composer_died`, `verified_by`, `verified_on`.

An entry missing any of these does not enter the training split. See
[DATASET.md](DATASET.md) for why `sequencer` in particular is not optional.

### Tier 2 — derived. Computed, never typed.

Key, mode, tempo, meter, bar count, note density, mean polyphony, pitch range,
velocity statistics, syncopation index, swing ratio, chord symbols, roman
numerals, melodic interval histogram, rhythm-cell histogram.

All of it is produced by `middaw.corpus.analyse` from the notes. Three
consequences, and each one matters more than it sounds:

- **It is never stale.** Recompute after any pipeline change; no re-annotation.
- **Two annotators cannot disagree** about the key, because neither is asked.
- **It is what the generator actually conditions on.** `CorpusPriors` reads
  the interval histogram, the rhythm cells and the roman numerals — nothing
  else. Tier 3 only selects *which* files are pooled.

Chord symbols come from the ScaleView Pro chord reader (see `middaw/scaleview.py`),
which reads intervals rather than matching a table of shapes. Measured on the
music21 core corpus it names 99.999% of 363,963 sonorities correctly, against
93.3% for a 62-pattern lookup table. That accuracy is the reason chord symbols
can be a *derived* field at all: at 93% you would be hand-correcting, and a
field you hand-correct belongs in tier 3, with all the disagreement that
implies.

Record a confidence where one exists. `key_confidence` is the share of
sounding time inside the detected scale; anything below ~0.85, or disagreeing
with the tags, is a file to look at by hand.

### Tier 3 — subjective. Closed vocabulary, multi-label, attributed.

`genres`, `moods`, `descriptors`, `roles` — each a list of ids from
`data/vocab/tags.json`.

Four rules:

1. **Multi-label, not single-label.** A piece is "cinematic" *and* "melancholy"
   *and* "sparse". Forcing one genre per file throws away most of the signal
   and produces arguments about whether something is lo-fi or R&B.
2. **Moods get coordinates, not just words.** Every mood in the vocabulary
   carries `valence` and `arousal` in [-1, 1]. Adjectives are what people type;
   the two numbers are what you can interpolate, cluster and sort by. Keep both.
3. **Every annotation is attributed.** The `annotations` list records
   `{field, value, by, confidence}` where `by` is `human`, `heuristic`,
   `model` or `source-metadata`. When a model-assisted pass turns out to have
   been systematically wrong about "dreamy", you can find and drop exactly
   those labels instead of re-annotating everything.
4. **Label the segment as well as the file.** Generation happens at 4–8 bars.
   A four-minute piece is one row of file-level labels and thirty rows of
   segment-level ones, and the segment rows are what training actually sees.

## The vocabulary is shared with the prompt parser

`data/vocab/tags.json` is read by **both** `middaw.corpus` and
`middaw.prompt`. One file, two consumers. This is not tidiness, it is the
mechanism that makes the product work:

- Every label in the dataset is reachable from something a user can type.
- Every word a user can type has somewhere in the dataset to look.
- Adding a genre adds it to both at once; they cannot drift apart.

Each tag also carries its *musical* priors — tempo window, mode weights,
progressions, accompaniment patterns, swing, density. That is what lets the
app answer a prompt sensibly on day one with an empty corpus, and it is what
corpus statistics then refine rather than replace.

### Growing the vocabulary from real prompts

Every `MusicSpec` carries `unmatched_terms`: the words in the prompt that the
lexicon did not recognise. The app shows them to the user ("Not understood
yet, so ignored: …") and they are the backlog. Sort by frequency and add the
top terms. That is the whole vocabulary-expansion process, and it is driven by
what people actually type rather than by what you imagine they will.

One warning from building this: **a word may describe the character of the
music only once.** "romantic" was both the Romantic era and the feeling, and "a
romantic waltz" resolved to Chopin rather than to tenderness. The era is now
`romantic_era`, matched only by "romantic era", "chopin", "nocturne" and so on.
Genre, mood and descriptor share one axis, and `middaw/vocab.py` now refuses to
load a vocabulary that puts one word on it twice — so this is caught when the
file is saved rather than in somebody's prompt.

The other axes — length, form, voice, role — are independent, and a word is
free to sit on several of them: "a soundtrack" is a cinematic style *and* a
sixty-four bar length; "vamp" is a loop *and* an ostinato.

**A sub-genre is a synonym unless it formulates notes differently.** The
labelling vocabulary carries hundreds of sub-genre names that all resolve to a
parent style, because the dataset should not fragment into tags with three
files each. `docs/GENRES.md` records which names earned their own tag and
which did not, style by style.

## Captions: the part that makes prompts work

You need (text, music) pairs to train a prompt-conditioned model, and nobody
is going to write a caption for 50,000 segments.

**Generate the captions from the structured labels.** A segment labelled
`{genres: [lofi], moods: [melancholy], mode: dorian, tempo: 78, meter: 4/4,
descriptors: [sparse]}` templates into:

> a sparse, melancholy lo-fi loop in D dorian at 78 BPM

Then paraphrase each template with an LLM into five or ten natural variants
("something wistful and unhurried to study to", "slow moody lo-fi keys") so
the model sees the variety of phrasing real users produce. The structured
labels stay the ground truth; the paraphrases are augmentation.

This is why the label schema *is* the prompt vocabulary, and why tier 3 must
be a closed list. Free-text tags cannot be templated into captions, and
captions are the supervision signal.

## Workflow

1. **Ingest.** `python -m middaw.corpus ingest` computes every tier-2 field
   and leaves provenance and tags empty.
2. **Clear rights.** Fill in tier 1. `python -m middaw.corpus validate
   --strict` fails until it is complete.
3. **Tag.** Tier 3, from the vocabulary. Heuristics first — mode and tempo
   already imply a lot, and a heuristic label attributed as `heuristic` is
   honest and cheap. Human passes only where it matters.
4. **Keep a gold set.** 100–200 files labelled carefully by hand, held out.
   Every time the heuristics or a model-assisted pass changes, score against
   the gold set. Without it you cannot tell improvement from drift.
5. **Measure agreement.** Have two people label the same 50 files. If they
   agree on genre less than ~80% of the time, the taxonomy is too fine — merge
   terms until they agree. Low agreement is a fact about your vocabulary, not
   about your annotators.

## What not to label

- **Anything derivable.** If `analyse.py` can compute it, it does not belong
  in tier 3. Duplicated facts diverge.
- **Anything you will not query.** "Recording quality" on symbolic data is
  meaningless. Every field costs annotation time forever.
- **Fine-grained subgenre, at first.** "house" before "deep/tech/progressive
  house". You can split a tag later using the derived features; you cannot
  merge back the annotator hours spent arguing about which one a file is.

## Worked example

```json
{
  "id": "commissioned-lofi-keys-014",
  "schema_version": 1,
  "file": "commissioned/lofi-keys-014.mid",
  "provenance": {
    "source": "commissioned",
    "source_url": "",
    "license": "owned-original",
    "composer": "A. Player",
    "composer_died": null,
    "sequencer": "A. Player",
    "sequenced_year": 2026,
    "rights_basis": "work for hire, copyright assigned in writing 2026-03-02",
    "commercial_use": true,
    "verified_by": "kallum",
    "verified_on": "2026-03-04",
    "sha256": "…"
  },
  "derived": {
    "key": "D Dorian", "tonic": 2, "mode": "dorian", "key_confidence": 0.97,
    "tempo": 78.0, "meter": "4/4", "bars": 8, "note_count": 142,
    "density": 4.4, "polyphony_mean": 2.1, "swing": 0.16,
    "syncopation": 0.38, "pitch_low": 38, "pitch_high": 79,
    "chords": ["Dmin9", "Gmin7", "Cmaj7", "Amin7"],
    "roman":  ["i9", "iv7", "bVIImaj7", "v7"],
    "intervals": { "1": 34, "-1": 29, "2": 18, "-2": 15, "3": 6 },
    "rhythm_cells": { "0.5,0.5": 22, "0.25,0.25,0.5": 14, "1": 9 }
  },
  "tags": {
    "genres": ["lofi"],
    "moods": ["melancholy", "calm"],
    "descriptors": ["sparse", "swung"],
    "roles": ["chords", "melody"]
  },
  "annotations": [
    { "field": "genres", "value": "lofi", "by": "human", "confidence": 1.0 },
    { "field": "moods", "value": "melancholy", "by": "human", "confidence": 0.8 },
    { "field": "descriptors", "value": "swung", "by": "heuristic",
      "confidence": 0.9, "note": "derived.swing = 0.16" }
  ]
}
```

Note what is *not* in `tags`: key, tempo, meter, swing amount. All derived.
`swung` appears as a descriptor only because it is a word a user might type,
and it is attributed to the heuristic that read it off `derived.swing`.
