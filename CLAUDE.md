# Middaw

Text prompt in, MIDI out. MIDI-first: notes are composed as notes. Nothing is
generated as audio and transcribed back — that inaccuracy is the thing this
project exists to avoid, so no part of the pipeline may reintroduce it.

## Working here

- **No dependencies.** Standard library Python, vanilla JS, no build step.
  Middaw reads and writes Standard MIDI Files itself (`middaw/midi.py`) rather
  than wrapping a library, because byte-level MIDI accuracy is the premise of
  the product and should be inspectable and tested. Do not add `mido`,
  `pretty_midi`, a web framework or a bundler without a real reason.
- **Run the tests before and after any change.** They take about a second:

  ```sh
  python3 -m unittest discover -s tests -t .
  ```

- **When fixing a bug, confirm the new test fails on the old code** before
  accepting it. A test that passes against the bug is worthless.
- Musical claims get verified, not assumed. `tests/test_render.py` asserts
  melodies stay in key, notes stay on an 88-key piano and what Middaw writes
  its own labeller reads back.

## `MusicSpec` is the contract

`middaw/spec.py`. A prompt is parsed *into* a spec; a spec is rendered *into*
MIDI; a corpus entry is described with the same vocabulary the spec uses. One
representation, so dataset labels, prompt words and generator controls cannot
drift apart. It is also the seam where a learned model replaces either half
later, one half at a time.

## One vocabulary, two consumers

`data/vocab/tags.json` is read by **both** `middaw/prompt.py` and
`middaw/corpus/`. Every dataset label is reachable from a prompt; every prompt
word has somewhere in the dataset to look. Adding a genre adds it to both.

**A word may not be both a genre and a mood.** "romantic" was both — the era
and the feeling — and "a romantic waltz" resolved to Chopin. The era is now
`romantic_era`, matched only by unambiguous names. Check every new tag against
the existing synonyms for this.

Anything the parser did not understand is reported on the spec as
`unmatched_terms` and shown to the user. That list is the vocabulary backlog;
it is driven by what people type, not by what we imagine they type.

## The ScaleView port

`middaw/scaleview.py` is a Python port of
[ScaleView Pro](https://github.com/KallumS/scaleview-for-reaper) (MIT, same
author). It is the authority here for scales, key-aware spelling and chord
naming — `middaw/theory.py` sources its scale table from it rather than
keeping a second copy.

`tests/test_scaleview.py` is every chord case from that project's Lua suite,
including the ones reported from REAPER and checked against Scaler 3. **A fix
to either project belongs in both** — they are independent copies of the same
engine, exactly as Pro and Simple are over there. The ranking constants and
their reasoning are ScaleView's; that repo's CLAUDE.md has the measurements
behind each one, and they were measured, not tuned by ear.

## Where the music theory lives

`docs/THEORY.md` records everything taken from the source material — Kallum's
own studies, Hutchinson's *Music Theory for the 21st-Century Classroom*, and
the ScaleView port — and marks each item implemented, partly implemented, or
not built. **Read it before adding musical behaviour**, and update the markers
when you build something. It is also the backlog: the closing section ranks the
gaps by how much they would improve the output.

The generator's harmony follows Hutchinson's four-function flowchart — tonic,
tonic prolongation, pre-dominant, dominant — not the usual three. Separating
tonic prolongation (vi, iii) from tonic is what stops vi resolving straight
back to I.

## Musical coherence is enforced, not hoped for

Two rules in `middaw/prompt.py` that exist because breaking them is instantly
audible:

- `_choose_progression` will not pair a major-key ii-V-I with a natural-minor
  melody. Deciding a progression's tonality from its *first* symbol is not
  enough — "ii7 V7 Imaj7 vi7" is major despite opening lower-case — so
  `progression_is_minor` looks for the chord built on the tonic.
- `progression_fit` excludes progressions that are not diatonic to the chosen
  mode. A bVI under a dorian tune is the single most audible way for a
  generator to sound assembled rather than written. Secondary dominants are
  exempt: they are deliberately chromatic and idiomatic where they are written.

Roman numeral degrees are measured against the **major** scale of the tonic,
always, with accidentals doing the rest. That is why `bVII` is the subtonic in
both C major and C minor, and why `V7` in a minor key carries a raised leading
tone.

## Corpus discipline

A MIDI file is a separate copyrightable work from the composition it
transcribes, so `provenance.sequencer` is required and `validate --strict`
fails without it. `ingest` fills in derived labels only and never invents
provenance, so a new file arrives failing validation and stays failing until a
human clears its rights. Only licences cleared for commercial use are pooled
into `CorpusPriors` by default.

Do not relax any of that for convenience. It is the difference between a
dataset and a liability. See `docs/DATASET.md`.

## Known limits, honestly

- Key detection in `middaw/corpus/analyse.py` recovers the tonic in about
  three quarters of a 120-piece sweep. Most of the residue is four-bar vamps
  that never state a tonic — `i-bVII-i-bVII` is as much G mixolydian as D
  dorian — and cadential material does much better. The weights were swept
  against *generated* music, which is a calibration set, not a corpus; re-check
  them once real files are in.
- The soundfont path (vendored file → CDN → built-in tone) has been exercised
  end to end against a locally built stand-in soundfont, but never against the
  real FluidR3 file, because the sandbox blocks both CDNs. Try it for real.
