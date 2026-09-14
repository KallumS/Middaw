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
- **How long, from what you call it**: a `riff` is 4 bars, a `loop` or `drum
  beat` 8, a `verse` 16, a `piece` 32, a `symphony` 64. Anything longer than a
  loop is laid out as sections — 32 bars is AABA, not one loop played eight
  times
- **72 genres**, across every family a listener would name — blues and
  boogie-woogie; jazz, bebop, big band, Dixieland, modal and smooth jazz;
  rock, punk, metal, prog, surf, rockabilly; soul, funk, disco, R&B;
  pop, synthpop, city pop, doo-wop, vaporwave; house, techno, trance, drum and
  bass, dubstep, UK garage, trap, boom bap, lo-fi, trip-hop, synthwave;
  country, bluegrass, folk, celtic, klezmer, polka, march, zydeco; salsa,
  samba, bossa nova, tango, flamenco, cumbia, reggaeton, bachata, mariachi;
  reggae and ska; afrobeat; classical, baroque, Romantic era, Renaissance,
  Impressionist, hymn; gospel, barbershop, lounge, new age, lullaby, cinematic,
  ambient, minimalism, chiptune, ragtime, waltz, ballad. Hundreds more
  sub-genre names route to the style whose notes they share — see
  **[docs/GENRES.md](docs/GENRES.md)**
- **16 moods**: sad, melancholy, dark, tense, epic, triumphant, happy,
  uplifting, dreamy, calm, playful, mysterious, romantic, nostalgic,
  aggressive, warm
- **Descriptors**: sparse, dense, high, low, loud, quiet, swung, straight,
  slow, fast, moderate, ornamented, plain
- **Voices**: melody, countermelody, ostinato, arpeggio, chords, bass — asked
  for by name, or chosen by the style (a baroque prompt is scored for two
  independent lines and a bass, not a tune over a pad)
- **Forms**: strophic, binary, repeated binary, ternary, AABA, rondo,
  seven-part rondo, medley, through-composed, sonata, fugue — named in the
  prompt, or chosen by the style
- **Cadences**: every section is built backwards from the way it ends —
  perfect and imperfect authentic, plagal, deceptive, half
- **Ornamentation**: passing tones, neighbours, appoggiaturas, escape tones,
  anticipations, suspensions and retardations — how much is a matter of style,
  and "ornamented" or "plain" in the prompt overrules it

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
- **[docs/GENRES.md](docs/GENRES.md)** — every style it can write, how each
  one's notes are formulated, the devices they share, and the names it
  deliberately does not map
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
