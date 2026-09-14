# How Middaw is put together

```
prompt ──► parse_prompt ──► MusicSpec ──► render ──► Song ──► MIDI bytes
              │                 ▲            │                    │
              │                 │            │                    ▼
     data/vocab/tags.json       │            │            web playback
              ▲                 │            │          (note list, not
              │                 │            │           a re-parsed file)
     middaw.corpus.stats ───────┘────────────┘
              ▲
     data/corpus/manifest.json  ◄── middaw.corpus.analyse ◄── sourced MIDI
```

## `MusicSpec` is the contract

Everything passes through one structure (`middaw/spec.py`): key, mode, tempo,
meter, bars, density, swing, extensions, register, velocity, progression,
accompaniment pattern, roles, plus the tags that produced them.

A prompt is parsed *into* a spec. A spec is rendered *into* MIDI. A corpus
entry is described with the *same vocabulary* the spec uses. One
representation, so the dataset labels, the prompt words and the generator
controls cannot drift apart.

It is also the seam where a learned model goes later: replace `parse_prompt`
with a text encoder, or replace `render` with a sequence model, one at a time,
without touching the rest.

## No dependencies, on purpose

Pure standard library, and a browser front end with no build step. `pip
install` nothing, `npm install` nothing. Middaw writes and reads Standard MIDI
Files itself (`middaw/midi.py`) rather than wrapping `mido`, because byte-level
MIDI accuracy is the entire premise of the product and it should be
inspectable and tested rather than delegated.

## Where the music comes from

With an empty corpus the generator is driven by explicit musical knowledge in
`data/vocab/tags.json` — tempo windows, mode weights, chord progressions,
accompaniment figures, swing and density per tag — plus:

- **`middaw/rhythm.py`** — a vocabulary of one-pulse rhythm *cells*, chosen by
  density, rather than a random grid. Idiomatic rhythm, and something the
  corpus can later supply statistics for.
- **`middaw/melody.py`** — a motif is generated once and then *varied* across
  the phrase (A, A', B, A''). Repetition with variation is what makes a line
  sound composed; a first-order Markov walk does not give you that however good
  its statistics are.
- **`middaw/embellish.py`** — non-chord tones, applied *after* the chord-tone
  line exists, because passing, neighbour, escape and the rest are
  relationships between three notes rather than kinds of pitch. Every label is
  then re-derived from the finished line, so what the generator reports is
  true of what it wrote.
- **`middaw/accompaniment.py`** — twelve named figures (alberti, stride,
  offbeat comping, waltz, rolled, ostinato…). Adding a style is a function plus
  a weight in the vocabulary.
- **`middaw/theory.py`** and **`middaw/scaleview.py`** — scales, roman numerals
  and chords.

Coherence is enforced rather than hoped for: `_choose_progression` will not
pair a major-key ii–V–I with a natural-minor melody, and `progression_fit`
excludes progressions that are not diatonic to the chosen mode — a bVI under a
dorian tune is the single most audible way for a generator to sound assembled
rather than written.

## The ScaleView port

`middaw/scaleview.py` is a Python port of
[ScaleView Pro](https://github.com/KallumS/scaleview-for-reaper), the same
author's REAPER script, and it brings two things:

**Spelling.** A scale carries a *letter* per degree as well as a semitone
interval, so Gb major reads Gb Ab Bb Cb Db Eb F rather than F# G# A# B C# D# F.
Middaw uses it for the key signature it writes into the MIDI and for every
chord symbol it shows.

**The chord reader.** `detect_chord` works out what a set of pitch classes is
called by reading the third, fifth and seventh and describing everything above
them, rather than matching a table of shapes. ScaleView measures it at 99.999%
of 363,963 sonorities in the music21 core corpus and 100% of all 17,688
three-to-seven-note voicings; a 62-pattern table scored 93.3% and 23.9% on the
same tests.

`tests/test_scaleview.py` is every chord case from that project's own Lua
suite, so the port cannot drift from the engine it came from. **A fix to either
belongs in both.**

## How the corpus feeds back in

`middaw/corpus/stats.py` turns labelled files into `CorpusPriors`. For a set
of tags it returns the melodic step distribution, the rhythm cells and the
chord progressions that files carrying those tags actually use — **blended
over** the built-in defaults, not replacing them:

```
influence = 0.75 * n / (n + 40)
```

One file nudges; two hundred steer. Nothing is special-cased in between, and
with no corpus at all every lookup returns the defaults unchanged. That is why
the app works before a single file has been sourced.

Only entries whose licence clears commercial use are pooled by default
(`commercial_only=True`), so an accidentally-added non-commercial file cannot
leak into output.

## Playback

The API returns both the `.mid` bytes and the note list. The browser schedules
**the note list**, so what you hear is exactly what was written — nothing is
inferred back out of a rendered file. Voice selection is vendored soundfont →
CDN soundfont → built-in additive tone, decided once and reported to the user.
