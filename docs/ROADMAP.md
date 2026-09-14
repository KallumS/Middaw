# Where this goes next

The order matters: each stage is useful on its own, and each one produces the
thing the next stage needs.

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

## Stage 2 — n-gram / HMM conditioned on tags

Melody as an order-3 model over (scale degree, duration) pairs, with chord
tones constrained on strong beats; progressions as a bigram model over roman
numerals. Small, fast, trainable on a few hundred files, interpretable, and
easy to check against the generated output because the same `analyse.py` reads
both.

Target: ~2,000 segments. Expect it to beat the rules on phrasing and lose to
them on long-range structure.

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
- **Drums.** Channel 10 plus the Groove MIDI Dataset (CC BY 4.0, commercially
  usable, expressively played) — the one genuinely clean, genuinely modern
  dataset available.
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
