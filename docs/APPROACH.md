# Calculate the music, measure the constants

The question this file answers: should Middaw generate by **calculating** a
piece from rules, or by **learning** one from a large MIDI collection?

Short answer: calculate. Use a corpus to fit the constants the calculation
needs, and to check that what comes out sits where real music sits. Do not use
it as material to search, recombine or memorise.

## Why calculation is the right spine for this product

"Music is mathematics and a song is a formula" is right in the way that
matters here, with one correction. A piece is not *one* formula; it is a small
stack of constrained choices, each with few parameters:

| Layer | The choice | Parameters |
| --- | --- | --- |
| Form | how many sections, which return, how each ends | form name, section lengths, cadence per section |
| Harmony | a grammar over chord functions, not a lookup table | mode, chromaticism, seventh appetite, functional bias |
| Rhythm | which cells, at what density, with what swing | density, swing, cell weights |
| Melody | a motif and its transformations over the chord tones | interval distribution, contour, register |
| Decoration | which non-chord tones, where | ornament rate |

That stack *is* the mathematics: a generative grammar with a parameter vector,
which is as much a formula as a closed-form expression is. Middaw already works
this way — `MusicSpec` is roughly thirty numbers, `render()` is a deterministic
function of the spec and a seed, and the same seed gives the same bytes every
time. Nothing is sampled from a corpus.

Four things follow from keeping it this way, and they are the product argument
rather than the aesthetic one:

- **Explainable.** Every note has a reason that can be named: this is the
  third of the pre-dominant, this is a passing tone between them, this bar is
  the consequent phrase and it half-cadences. `Generation.to_dict()` already
  reports the chords, the sections and the ornaments.
- **Editable.** Because the piece is parameters, a user can change one and
  regenerate: keep the progression, change the melody; keep everything, drop
  the density. That is what a producer actually wants and it is nearly
  impossible to offer on top of an end-to-end model.
- **Small.** The whole generator is a few hundred kilobytes of Python and one
  JSON file. It runs anywhere, instantly, offline.
- **Clean.** Parameters measured across thousands of files are statistics about
  a style. Weights that have memorised phrases are a liability. See
  [DATASET.md](DATASET.md).

## What calculation cannot give you

Being honest about the ceiling, because this is where a corpus earns its place:

1. **The constants.** No amount of theory tells you how often a bebop line
   leaps rather than steps, how long a house phrase actually is before it
   changes, or what fraction of country melodies end on the third. These are
   facts about a repertoire. They are measured, not derived. Middaw's are
   currently set by hand from the theory books and by ear — which is exactly
   the part a dataset should replace.
2. **Idiom that nobody wrote down.** Some of it is in the books (the skank is
   on the offbeat, the montuno is syncopated) and Middaw encodes it. The rest
   is in the files.
3. **Surprise.** Rules give coherence. They do not give the moment where a
   piece does something unexpected and right. Adding noise to a parameter is
   not surprise, it is noise.
4. **Taste.** There is no formula for "this melody is good". A rules system is
   capped at the taste of whoever set its constants.

## So: three uses for a corpus, in order of value

**1. Calibration — fit the constants.** For each style, measure the interval
distribution, the rhythm cells, the phrase lengths, the chord-transition
frequencies, the cadence mix, the ornament rate, the register spread. The
output is a table of numbers that lands in `CorpusPriors` and blends over the
defaults — `middaw/corpus/stats.py` already does this, and is waiting on data.
The artefact shipped is numbers about a style, not anybody's melody.

**2. Validation — the corpus as a test set.** This is the most valuable thing
available today and it is not on the roadmap because it was not obvious.
`middaw/corpus/analyse.py` reads a MIDI file back into the same vocabulary the
generator writes from, which means real files can answer two questions Middaw
currently answers only against itself:

- *Does the analysis work?* Key detection recovers the tonic in about
  three-quarters of a sweep — **of generated music**. That is a calibration
  set, not a corpus. It has never been run against real files.
- *Does the generation land in the right place?* Take the distributions real
  files of a style occupy, generate a hundred pieces in that style, and compare.
  If Middaw's bebop sits outside the interval distribution of actual bebop, the
  constants are wrong and now we know by how much.

This turns a MIDI folder into a measuring instrument. No trained weights, no
copied material, and it tells us which of the rules are actually wrong.

**3. Learning — but only ever to produce parameters.** The ladder, in the order
each step becomes worth doing:

- **A. Constants by hand, from theory.** Where Middaw is now. Works, and it is
  why the output is already stylistic.
- **B. Constants measured per style.** Stage 1 of [ROADMAP.md](ROADMAP.md).
  Needs cleared data and nothing else.
- **C. Prompt → spec, learned.** The interesting one. Train a model to predict
  the *parameter vector* from the text, while `render()` stays exactly the same
  deterministic function. This is a small regression and classification
  problem, not a sequence model: it trains on a few thousand labelled files,
  it is inspectable (you can read the spec it predicted and argue with it), and
  it structurally cannot emit somebody else's melody.
- **D. A sequence model for contour only.** If phrasing still sounds
  mechanical, let a small model choose the melodic contour — but inside the
  grammar, so the harmony, the key and the cadence remain hard constraints and
  the model contributes shape rather than pitches it remembered.

Nothing above stage C requires a large model, and stages C and D degrade
gracefully: when the model has nothing useful to say about a prompt, the rules
still answer it.

## The 20GB folder, specifically

A large general MIDI collection is almost certainly a mixture of transcriptions
of copyrighted songs. Two clearances are needed for any of it to be shipped
commercially — the composition and the MIDI file itself, which is a separate
copyrightable work — and a bulk collection has neither. The project's rule
stands: nothing enters `CorpusPriors` for commercial use without cleared
provenance, and `validate --strict` enforces it.

That does not make the folder useless. Ranked by how much it gives against how
much it exposes:

1. **Measure our own accuracy with it, locally** (use 2 above). Nothing derived
   from it ships. This is the first thing to do.
2. **Triage it.** 20GB is likely a few hundred thousand files, and most of them
   are not useful: duplicates, karaoke files, general-MIDI arrangements of
   everything in one track, broken quantisation. The useful subset is
   solo-or-small-ensemble, cleanly played or cleanly quantised, and
   identifiable by style. `middaw.corpus ingest` already derives the labels
   needed to sort that out, and the triage is worth doing before any question
   of rights arises.
3. **Use it to find out which styles need cleared files most** — i.e. where our
   hand-set constants are furthest from reality. Then commission or source
   those specifically, which is a much smaller and cheaper problem than
   clearing a whole collection.

Getting a lawyer to look at any commercial use of measured statistics is a
sensible step before stage B ships, and is not a question this file can settle.

## The decision

**The renderer stays a calculator.** Learning may replace how the parameters
are chosen; it may never replace how the notes are written. The seam is
`MusicSpec`, and it was put there for exactly this.
