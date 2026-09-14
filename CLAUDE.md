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

**A word may describe the character of the music once.** Genre, mood and
descriptor are one axis and they argue with each other: "romantic" was both an
era and a feeling, and "a romantic waltz" resolved to Chopin. The era is now
`romantic_era`, matched only by unambiguous names. `_check_axes` in
`middaw/vocab.py` refuses to load a vocabulary that breaks this, so the failure
is at load time rather than in somebody's prompt.

**The other axes stack.** Length, form, voice and role are independent of
character and of each other, so one word can carry several meanings at once: "a
soundtrack" is cinematic *and* sixty-four bars, "vamp" is eight bars *and* an
ostinato. Matching claims one axis at a time, which is also why a longer phrase
on one axis no longer swallows a shorter one on another — "a waltz piece" is a
waltz that happens to be thirty-two bars long.

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

## Length and form

`middaw/form.py`. Length is inferred from what the prompt calls the thing and
snapped to the ladder 4, 8, 16, 32, 64 — an explicit bar count is taken
literally, and a long progression (a twelve-bar blues) overrides the ladder.

Anything past a loop is laid out as **sections**, because a 32-bar generation
is not a longer loop. Sections sharing a letter share their harmony and their
melodic motif (`generate_melody` takes a separate `motif_rng` for exactly
this), so the return of A is heard as a return; contrasting sections get their
own progression and are pushed away in density, register and dynamics.

## Cadences come first, then the harmony

`middaw/cadence.py`. A section is given its ending *before* its progression is
written, and `generate_progression(cadence=...)` chains backwards from it. The
closing chords are then protected from chromatic decoration — the cadence is
the point of the phrase, so a tritone substitute must not eat it.

Sections sharing a letter are the **same music re-ended** (`recadence`), not
different music. A refrain that stops on the dominant and the same refrain that
closes must be recognisably one tune.

A minor key borrows a major V at a cadence. A **modal** key does not: raising
dorian's flat seventh turns it into minor. `MINOR_KEY_MODES` in
`middaw/functional.py` is the list that decides, and it deliberately excludes
dorian, phrygian and mixolydian.

## Four tracks, always

`middaw/parts.py`. Every generation is the same four MIDI tracks in the same
order on the same channels: **melody, countermelody, harmony, bass**. That is
the standard Western texture, and keeping it fixed means a player can assign
one instrument per part once and have every result land on the same four slots.
A part the prompt deliberately silenced ("just a bassline") is still written,
just empty — the slots do not move.

The harmony part is one job done one of three ways: comped `chords`, an
`ostinato`, or an `arpeggio`. A style picks the treatment (`GENRE_TREATMENT` in
`middaw/prompt.py`), a prompt can ask for one by name, and it is carried on the
spec as `spec.harmony` and on the track as `detail`. **It never gets its own
track** — a repeating figure and a comping piano are the same part played
differently, not two parts.

`middaw/voices.py` writes the lines. The countermelody is a real second voice —
it moves where the melody rests, moves contrary to it where it can, stays under
it, and refuses parallel fifths and octaves. `_makes_parallel` compares each
voice against the other *at the same moment*; comparing the current melody note
against both counter notes looks plausible and detects nothing.

An ostinato figure is invented once for the whole piece, not once per section.
That repetition is what makes it an ostinato.

## Genres are note-formation rules, not sounds

`docs/GENRES.md` is the record for every style: what it is, how its notes are
formulated, and why each dial in `data/vocab/tags.json` is set where it is.
**Read it before adding or retuning a genre**, and add the reasoning there when
you do.

A genre entry sets all fourteen dials or it is not finished, and
`tests/test_vocab.py` enforces that: every mode, meter, figure and chord symbol
must exist, every style must render, and every mode a style names must have a
listed progression that actually fits it. A progression that does not fit is
never chosen, so an unfitting list is not a weak list — it is dead data.

Sub-genres that differ only in production, scene or speed are **synonyms of the
parent**, not new entries. A new entry has to formulate notes differently.
Where a style's identity is timbre rather than pitch — noise, shoegaze, most of
glitch — Middaw declines it and `docs/GENRES.md` says why. That list is not a
gap to be closed by approximating; the real gaps are named separately there.

The blues scales are the one deliberate ambivalence: minor-ish melodically, and
dominant harmonically. `BLUES_MODES` in `middaw/theory.py` lets them take their
harmony from mixolydian as well as their own parent, and lets a progression
over them be of either tonality, because a twelve-bar is I7–IV7–V7 whatever the
tune over it is doing. Without that rule a blues melody refuses its own
harmony.

## Non-chord tones are decided last

`middaw/embellish.py`. A non-chord tone is not a kind of pitch, it is a
*relationship*: the same D is a passing tone, a neighbour or an escape
depending on what surrounds it. So decoration is a **post-pass over a finished
chord-tone line**, never a choice made while the line is being written — that
is the only place the approach and the departure are both known.

Invariants, all of them load-bearing:

- **Labels are re-derived, not remembered.** `_verify` classifies every
  applied note again from the finished line and drops or re-labels anything
  that no longer matches. A later insertion can turn a neighbour into an
  escape; the music is still fine, only the label was wrong, and a generator
  that reports a label it did not write is worse than one that reports none.
- **Everything added is a scale degree**, so the in-key invariant
  `tests/test_render.py` asserts survives decoration.
- **Nothing may come between a suspension and its resolution.** The boundary
  pass returns a `frozen` set covering both notes and the split pass honours
  it, or the suspension is simply a wrong note.
- **The last note of a section is never touched.** The cadence is the point of
  the phrase.
- **A melodic line stays monophonic.** `_monophonic` trims each note to the
  next onset; decoration works in the *slot* between onsets, not in the
  sounding duration, because melodies shorten notes for articulation and so
  are almost never contiguous.

Choose the *device* first, then its direction. Weighting the forms instead
over-represents whichever device has two of them.

## The renderer is a calculator

`docs/APPROACH.md`. A piece is a parameter vector plus a deterministic
procedure, and that is deliberate: it is what makes the output explainable,
editable, small and clean of other people's material. A corpus exists to **fit
the constants** that procedure uses and to **measure** how far its output sits
from real music — not to be searched, recombined or memorised.

So learning may replace how a spec is chosen; it may never replace how the
notes are written. `MusicSpec` is the seam, and it is there for exactly this.

## Measuring against real music

`middaw/corpus/measure.py`, run as `python3 -m middaw.corpus measure <folder>`.
It reads MusicXML scores and any RomanText analyses beside them, and reports
how close our key detection and our harmonic analysis are to what a human
wrote. `middaw/corpus/notation.py` reads both formats with the standard
library, for the same reason `middaw/midi.py` writes MIDI by hand.

Measuring is not ingesting: it reports numbers about a folder and copies
nothing into the corpus, which is what makes it usable on files whose rights
are not cleared. See `docs/DATASET.md` before pointing it anywhere.

**A number measured against our own output is not a measurement.** Every
accuracy figure in this project before this tool existed was produced by
generating music and analysing it, which measures the generator against
itself. When the two sets disagree, the real music is right.

And when a measurement collapses, suspect the reader first: the first run said
key detection was 45% accurate, and the actual fault was that 156 of the 410
chorales mark the soprano minor and the other three parts major, so reading
every part and keeping the last called them all major.

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

- Key detection in `middaw/corpus/analyse.py` names tonic and mode exactly for
  **74.9%** of 410 Bach chorales and finds the tonic for **80.2%** — measured,
  not estimated. Most of the residue is a minor key named as one of its modes
  (B minor read as B dorian), because the collection is picked from the major
  scale and a raised leading tone moves it; the rest is four-bar vamps that
  never state a tonic, where `i-bVII-i-bVII` is as much G mixolydian as D
  dorian. Harmonic analysis agrees with a human analyst's root on **80.5%** of
  1,041 chords.
- Both of those are chorale numbers, and chorales are the easy case. Against
  535 songs, quartets and sonatas with human analyses (When in Rome), key
  detection drops to **53.4%** and harmonic analysis to **62.7%** of 52,685
  chords. An arpeggiated accompaniment under a modulating song is a different
  problem from four voices in crotchets, and the window-namer is not good at
  it yet. Quote the harder number.
- **How stepwise a melody should be is a per-style constant, and ours are not
  measured.** Bach's chorale melodies step 67% of the time; a nineteenth-century
  song steps 47% and repeats a note 23% of the time, because it is setting
  syllables. Middaw writes 49% for a hymn and 59% for a romantic-era piece —
  wrong in both directions, because the number was never a number. What holds
  across both corpora: real melodies turn back after a leap more reliably than
  ours (92% against our 77%).
- The soundfont path (vendored file → CDN → built-in tone) has been exercised
  end to end against a locally built stand-in soundfont, but never against the
  real FluidR3 file, because the sandbox blocks both CDNs. Try it for real.
