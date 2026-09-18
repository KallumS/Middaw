# Where this goes next

The order matters: each stage is useful on its own, and each one produces the
thing the next stage needs.

The principle underneath the order is in [APPROACH.md](APPROACH.md): the
renderer stays a calculator, and learning is only ever allowed to choose the
parameters it calculates from. Read that first — it also says what a corpus is
for, which is not what most people assume.

## Stage 0 — where it is now

Rules and music theory, no corpus. Answers any prompt immediately, sounds
plausible, is completely explainable and completely deterministic given a seed.
Its ceiling is real: it will never surprise you, because nothing in it was
learned.

## Stage 1 — corpus statistics (implemented, needs data)

`CorpusPriors` already blends corpus melodic intervals, rhythm cells and chord
progressions over the defaults. It needs files. **This is the stage that is
blocked on sourcing, not on code**, which is why `DATASET.md` and
`LABELLING.md` are the priority and not the model.

Target: ~500 cleared, labelled files across 6–8 genres. Enough for phrasing to
start sounding like the source material.

## Stage 1b — the corpus as a test set

Before any of it trains anything, real files can measure how wrong the current
constants are. `middaw/corpus/analyse.py` reads MIDI back into the same
vocabulary the generator writes from, so a folder of real music answers two
questions Middaw currently only asks of itself: does the analysis recover what
a human would say about a file, and do Middaw's own generations sit inside the
distributions real files of that style occupy?

Key detection is the standing example — it recovers the tonic about
three-quarters of the time **against generated music**, which is a calibration
set rather than a corpus. This stage needs no clearances, because nothing
derived from the files is shipped.

## Stage 2 — n-gram / HMM conditioned on tags

Melody as an order-3 model over (scale degree, duration) pairs, with chord
tones constrained on strong beats; progressions as a bigram model over roman
numerals. Small, fast, trainable on a few hundred files, interpretable, and
easy to check against the generated output because the same `analyse.py` reads
both.

Target: ~2,000 segments. Expect it to beat the rules on phrasing and lose to
them on long-range structure.

## Stage 2b — prompt to spec, learned

The step most worth taking, and the one that fits the architecture: train a
model to predict the *parameter vector* from the prompt, and leave `render()`
as the same deterministic function it is now. A spec is about thirty numbers,
so this is regression and classification rather than sequence modelling — it
trains on a few thousand labelled files, the prediction can be read and argued
with, and it structurally cannot emit someone else's melody.

## Stage 3 — a small transformer

Tokenise with a REMI-style scheme (bar, position, pitch, duration, velocity),
condition on the templated caption as a prefix. Small — 10–30M parameters.
Anything larger will overfit the corpus you can legally build.

Target: ~10,000+ labelled segments before this beats stage 2. Below that it
memorises. Keep the rule generator as the fallback for prompts the model has no
data for, and as the structural scaffold the model fills in — a hybrid will
beat either alone for a long while.

## Product work that does not wait for models

- **Instruments.** `Track.program` is already carried through; the front end
  is piano-only by choice. Multi-timbral playback is a soundfont selector, not
  a rearchitecture.
- **Drums.** ✅ Built. Channel 10, a fifth part, 29 patterns written the way
  progressions are written, and the feel measured from the Groove MIDI Dataset
  (`docs/MEASUREMENTS.md`). What is left is the gap the comparison shows: our
  grid is a clean pattern where a drummer's is a cloud of variation around one.
  Per-bar variation and a proper swing constant are the next two steps.
- **Edit, don't just regenerate.** Regenerate one part against the others,
  lock a progression and vary the melody, nudge tempo/density with the spec
  exposed as controls. The `MusicSpec` is designed for this.
- **Export stems** — one `.mid` per part, which is what a producer actually
  wants to drop into a DAW.
- **Vocabulary from the backlog.** `unmatched_terms` is already collected; log
  it, sort by frequency, work down the list.

## The honest risk

A model trained only on public-domain material writes public-domain-sounding
music. Commissioned original MIDI in target genres is the thing that fixes
that, and it is a budget decision rather than a research one. See the end of
[DATASET.md](DATASET.md).
