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

`python3 -m middaw.corpus measure <folder>` does it, against MusicXML scores and
any RomanText analyses sitting beside them. What the first run found, against
410 Bach chorales and the eighteen of them that carry a human analysis:

| | |
| --- | --- |
| key: tonic and mode | **74.9%** of 410 chorales |
| key: tonic only | **80.2%** |
| named the relative key by mistake | 2.7% |
| harmony: same root as the analyst | **80.5%** of 1,041 analysed chords |
| harmony: same root and quality | **78.7%** |
| numerals our theory could not express | 0 of 1,041 |

Three things came out of that first run, and only one of them was about the
generator:

- **A bug in the reader, not the analyser.** In 156 of the 410 chorales the
  soprano part is marked minor and the lower three major, on the same key
  signature. Reading every part and letting the last one win called a third of
  the collection major that is not — and the "key detection is only 45%
  accurate" panic that produced was entirely our own mistake.
- **A real fix, worth 12 points.** Key detection took the lowest note of the
  last few beats as the final bass. At a cadence the dominant sits below the
  tonic that follows it, so a I–V–I in C was read as G mixolydian. Reading the
  bass of the *last chord* instead moved the chorales from 62% to 75% and the
  generated set from 51% to 73% — the same change helping both, which is how
  you tell a fix from a tuning.
- **Something the generator is measurably wrong about.** Bach's chorale
  melodies move by step 67% of the time. Middaw's move by step 49% and repeat
  a note 19% of the time against Bach's 15%. The interval distributions are
  0.19 apart. "Mostly stepwise" was marked as implemented; it is implemented
  and it is set too low.

Pointed at [When in Rome](https://github.com/MarkGotham/When-in-Rome) — 535
scores with a human analysis, mostly nineteenth-century songs, string quartets
and piano sonatas rather than chorales — the same tool says something harder:

| | chorales | songs, quartets, sonatas |
| --- | --- | --- |
| key: tonic and mode | 74.9% of 410 | 53.4% of 761 |
| harmony: same root as the analyst | 80.5% of 1,041 chords | 62.7% of 52,685 |
| harmony: same root and quality | 78.7% | 56.6% |
| analyst numerals we could not express | 0 | 72 (0.1%) |

That is the honest shape of it. Four voices moving in crotchets is the easiest
harmony there is to read; an arpeggiated piano accompaniment under a singer,
modulating, is not, and our window-naming loses eighteen points when it meets
one. Both numbers are worth having, and the second is the one to quote.

The melody comparison had to be fixed before it meant anything: the top line of
a piano staff is not a melody, it is whichever note happens to be highest, and
measuring against it produced octave leaps and a stepwise share that meant
nothing. Measured against the 396 scores that do have a named vocal line:

| | Lieder voice | Middaw |
| --- | --- | --- |
| stepwise | 46.6% | 59.4% |
| repeated note | 22.7% | 8.5% |
| leap turns back | 91.8% | 77.0% |

Which complicates the chorale finding rather than confirming it. A chorale
melody steps 67% of the time; a nineteenth-century song melody steps 47% and
repeats a note 23% of the time, because it is setting syllables. There is no
one right amount of stepwise motion — it is a per-style constant, which is
exactly what the generator's vocabulary is made of and exactly what a corpus is
for. What does hold across both: real melodies turn back after a leap more
reliably than ours do.

Everything else the run touched was left alone on purpose. A sweep of the
chord-window constants moved root accuracy between 80.4% and 81.4% across
every setting, and the key-detection weights bought a point on the chorales for
a point on the generated set — both of which are what noise looks like, and
neither of which is a reason to change a constant. Eighteen analyses of one
genre by one composer is a keyhole, not a window.

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

The same test applies to the obvious "but this one is public domain" candidate,
the music21 core corpus: its compositions are clear, its *encodings* are
licensed to music21 with commercial restrictions, and its largest repertory is
non-commercial by name. [DATASET.md](DATASET.md) has the verified inventory and
the quotes. It is a fine measuring instrument and a poor pool to ship from.

## The decision

**The renderer stays a calculator.** Learning may replace how the parameters
are chosen; it may never replace how the notes are written. The seam is
`MusicSpec`, and it was put there for exactly this.
