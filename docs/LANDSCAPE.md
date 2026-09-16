# Where Middaw sits

Three projects doing something adjacent, read in September 2026 to see what
they solved that we have not, and what we are doing that nobody else is. No
code was taken from any of them; this is a read of their repositories and their
own documentation.

| | Middaw | [BeatFlow](https://github.com/the0cp/beatflow) | [LLMidi](https://github.com/DirtyBeastAfterTheToad/LLMidi) | [midi-sketch](https://github.com/libraz/midi-sketch) |
| --- | --- | --- | --- | --- |
| Where the music comes from | rules in code | an LLM, prompted | an LLM, prompted | rules in code |
| Input | free text | free text | free text | numeric preset ids |
| Runs offline | yes | no (API key) | yes, with a local GGUF | yes |
| Deterministic from a seed | yes | no | no | yes |
| Language | Python, stdlib only | Python + Next.js | C++/JUCE | C++17, no deps |
| Size | ~6,600 lines + 2,200 of tests | ~600 lines of Python + a web app | ~4,300 lines | ~182,000 lines |
| Tracks | 4, fixed | chords, bass, drums | whatever the model returns | 9 |
| Drums | no | yes | via the model | yes |
| Delivery | local web app | web app with a piano roll | **VST3 plugin, inside the DAW** | WASM library, CLI, live demo |

## What each of them actually is

**BeatFlow** treats the LLM as the composer. Two prompts — one asks for a song
structure as JSON (sections, energy, chord names), one asks per section for
rhythm as "duration streams" like `x8n` and `1_16n` — and a 215-line Python
engine turns the answers into MIDI. The music theory lives in the prompt, not
the program: the engine is a chord-name parser and a duration parser. What it
has that we do not is drums, a browser piano-roll editor, and a per-section
energy curve. What it pays for that is an API key, a network round trip and a
different answer every time.

**LLMidi** is the one with the distribution idea worth stealing: it is a JUCE
**VST3 plugin**, so the prompt box is inside Ableton or FL Studio and the MIDI
arrives on a track rather than in a download. It runs a local GGUF model
through llama.cpp offline, or has you paste the prompt into a web chatbot and
paste the JSON back. Its musical knowledge is a 40-line validator that checks
bars, steps and note ranges — everything else is the model's.

**midi-sketch is the closest thing to a peer**, and in several places it is
ahead of us. It is rule-driven C++17 with no dependencies, deterministic from a
seed, nine tracks including drums and a vocal line, voice leading, non-chord
tones, chord extension planning, Euclidean rhythms, emotion curves, 139 test
files, a WASM build and a live demo. It also — and this is the part worth
knowing — **measures generated melodies against profiles built from a corpus of
real songs**, which is the same idea as `docs/MEASUREMENTS.md`.

## Where we are ahead

1. **The prompt is the interface.** midi-sketch takes `style_preset_id = 7`;
   we take "a klezmer hora in D, ornamented, 16 bars". That is 72 styles and
   ~1,100 phrases across five independent axes, and the words that miss are
   reported back as the vocabulary backlog. Neither rule-driven peer has any
   natural-language layer at all, and the two that do have one have no theory
   underneath it.
2. **The theory is the program, and it is written down.** 2,500 lines of
   `docs/` record where every rule came from and mark what is built, partly
   built or not built. BeatFlow and LLMidi cannot answer "why that chord";
   we can name the function, the cadence and the non-chord tone for every note
   and hand the answer back through the API.
3. **The reference data is free and the harness ships.** midi-sketch's
   reference corpus is, in its own words, "licensed material that is not
   distributed with the repository" — so nobody else can reproduce its targets.
   Ours is CC0 and CC BY-SA notation, the readers are in the repo, and anyone
   can run `python3 -m middaw.corpus measure` and get our numbers.
4. **Rights discipline as a feature.** `provenance.sequencer` is required,
   `validate --strict` fails without it, and `docs/DATASET.md` records the
   licence of every source we looked at. For a product that ships music this is
   the difference between a dataset and a liability, and none of the three has
   an equivalent.
5. **Determinism with an audit trail.** midi-sketch is deterministic too, but
   we also report the spec, the sections, the chord names and every
   embellishment for a given seed.

## Where we are behind

1. **No drums.** Three of three have them. Half of the styles in
   `docs/GENRES.md` keep most of their identity in a kit we do not write. This
   is the single biggest hole in the output.
2. **No editing.** BeatFlow has a piano roll; we render a read-only view. A
   generator you cannot adjust is a slot machine.
3. **Four tracks against nine.** Ours is a deliberate contract, but a pad, a
   counter-riff, a guitar and an effects layer are real parts of an
   arrangement, and midi-sketch writes them.
4. **Not in the DAW.** LLMidi's VST3 is the right shape for the actual user.
   Exporting stems and a plugin wrapper are both on the far side of the
   product, not the theory.
5. **No live demo.** midi-sketch has a hosted page anyone can click. We have a
   local server.
6. **Nothing learned yet.** Stage 1 of `docs/ROADMAP.md` is still waiting on
   cleared data.

## What we are doing that nobody else is

- Naming every probability in the generator and **measuring the output against
  real music**, then publishing both numbers — including the ones that say we
  are wrong (`docs/MEASUREMENTS.md`).
- Treating **genre as a set of note-formation rules** rather than a label, with
  the reasoning for every dial written down (`docs/GENRES.md`).
- Deciding non-chord tones as a **post-pass with re-derived labels**, so what
  the generator reports is always true of what it wrote.
- Reading MusicXML, `**kern` and RomanText **with no dependencies**, so the
  measuring instrument is as inspectable as the generator.

## How far from the finish line

For "a text box that writes usable MIDI", the honest answer is that the
*musical* core is most of the way there and the *product* is not.

| Milestone | State |
| --- | --- |
| Prompt → spec → MIDI, offline, deterministic | done |
| Harmony, cadences, form, four parts, non-chord tones | done |
| 72 styles with measured constants | done for 4 styles, defaults for the rest |
| Measured against real corpora | done, and honest about the gaps |
| **Drums** | not started — the biggest gap |
| **Edit and regenerate a part** | not started |
| **Stems, plugin, hosted demo** | not started |
| Corpus-fitted constants for every style | blocked on cleared data, not on code |

Two or three focused pieces of work — drums, per-part regeneration, and a
hosted demo — would put Middaw level with the best of these on features while
keeping the two things none of them have: it explains itself, and it is clean.
