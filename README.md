# Middaw

Text prompt in, MIDI out. **MIDI-first**: notes are composed as notes and
written straight to a Standard MIDI File. Nothing is generated as audio and
transcribed back, so nothing is approximated.

```
What do you want to create?
> a sad lo-fi piano loop in F minor at 82 bpm

lofi, sad | F Minor (Natural) | 82 BPM | 4/4 | 16 bars
Fmin7  Bbmin7  Eb7  Abmaj7   repeats every 4 bars
```

## Run it

No dependencies. Python 3.11+, and a browser.

```sh
python3 server/app.py           # http://127.0.0.1:8765
```

Optional, for a real piano instead of the built-in fallback tone:

```sh
python3 tools/fetch_soundfont.py
```

From the command line:

```sh
python3 -m middaw "a celtic jig" -o jig.mid
python3 -m middaw "epic cinematic build in 3/4, 32 bars" --seed 42 --json
```

Tests:

```sh
python3 -m unittest discover -s tests -t .
```

## What it understands

Anything it does not understand it says so, rather than ignoring it silently —
those words are the backlog for the vocabulary.

- **Stated outright, and always obeyed**: `in F# minor`, `at 92 bpm`, `6/8`,
  `16 bars`, `30 seconds`, `D dorian`, `seed 4242`
- **24 genres**: lo-fi, jazz, blues, classical, baroque, Romantic era, folk,
  celtic, pop, ballad, ambient, cinematic, house, techno, trap, R&B, gospel,
  waltz, ragtime, tango, bossa nova, minimalism, chiptune, rock
- **16 moods**: sad, melancholy, dark, tense, epic, triumphant, happy,
  uplifting, dreamy, calm, playful, mysterious, romantic, nostalgic,
  aggressive, warm
- **Descriptors**: sparse, dense, high, low, loud, quiet, swung, straight,
  slow, fast, moderate
- **Roles**: melody, chords, bass, arpeggio, ostinato

All of it lives in one file, [`data/vocab/tags.json`](data/vocab/tags.json),
which is read by both the prompt parser and the corpus labeller. Adding a
genre adds it to both at once.

## Layout

| | |
| --- | --- |
| `middaw/` | the generator: prompt → spec → notes → MIDI |
| `middaw/scaleview.py` | scales, key-aware spelling and the chord reader, ported from [ScaleView Pro](https://github.com/KallumS/scaleview-for-reaper) |
| `middaw/corpus/` | the labelled dataset: schema, analysis, statistics, CLI |
| `server/app.py` | the local web app (standard library only) |
| `web/` | one screen, no build step |
| `data/vocab/tags.json` | the shared vocabulary |
| `docs/` | the design decisions |

## Documentation

- **[docs/THEORY.md](docs/THEORY.md)** — everything the generator knows about
  music, where it came from, and which parts are built yet
- **[docs/LABELLING.md](docs/LABELLING.md)** — how to label the dataset, and
  why the label schema is also the prompt vocabulary
- **[docs/DATASET.md](docs/DATASET.md)** — sourcing MIDI you are actually
  allowed to use, and the two-clearance problem that catches everybody
- **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)** — how the pieces fit
- **[docs/ROADMAP.md](docs/ROADMAP.md)** — rules → corpus statistics → model

## The corpus

Empty, deliberately. The generator works without it, driven by explicit
musical knowledge, and improves as files arrive — one file nudges it, two
hundred steer it.

```sh
python3 -m middaw.corpus ingest     # derive labels from the notes
python3 -m middaw.corpus validate   # check rights and tags
python3 -m middaw.corpus stats      # what the corpus teaches the generator
```

A freshly ingested file has no provenance, and `validate --strict` fails until
a human fills it in. Only entries whose licence clears commercial use are used
for generation by default. This is enforced rather than documented because
"we'll sort the licences out later" is how a corpus becomes unusable.

## Licence

MIT. `middaw/scaleview.py` is ported from ScaleView for REAPER, also MIT.
