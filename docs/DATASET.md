# Sourcing MIDI you are actually allowed to use

## The one thing that catches everybody

**A MIDI file is a separate copyrightable work from the composition it
transcribes.** Bach died in 1750, so the *Well-Tempered Clavier* is public
domain everywhere. The MIDI file of it that someone sequenced in 2004 is
their work, and it is under copyright unless they said otherwise.

So "public domain music" is not a licence. Every file needs **two** clearances:

| | what you need |
| --- | --- |
| the **composition** | out of copyright, or licensed, or written by you |
| the **sequence/transcription** | explicitly licensed (CC0, CC BY, MIT), or made by you |

This is why `provenance.sequencer` is a required field in the schema and why
`validate` refuses an entry without it. It is the field people forget, and it
is the one that ends the project if it is wrong at scale.

## The second thing: "public domain" is a local claim

US: published before 1931 is public domain (rolling). EU and UK: life of the
author plus 70 years. They disagree constantly — Rachmaninoff (d. 1943) is
public domain in the US and will not be in the EU until 2044.

Store `composer_died` and decide by **the strictest jurisdiction you intend to
operate in**, not the most convenient one. The schema requires that date for
any `PD` claim precisely so the whole corpus can be re-judged later against a
different rule without re-researching every file.

## Sources worth using

### Tier 1 — clean, use freely

| Source | What | Licence | Notes |
| --- | --- | --- | --- |
| **Mutopia Project** | ~2,000 classical scores | CC0 / CC BY-SA / PD | LilyPond source, exports MIDI. Per-piece licences — read each. |
| **KernScores / CCARH** (Stanford) | Bach chorales, Beethoven sonatas, Haydn quartets, Josquin, Scarlatti | mostly free for research and reuse | Humdrum `**kern`, converts cleanly to MIDI. The best-encoded classical data anywhere. |
| **Essen Folksong Collection** | ~20,000 folk melodies, European and Chinese | free | Monophonic. Superb for melody and phrase statistics. |
| **Nottingham Music Database** | ~1,200 British/Irish folk tunes | traditional, freely distributed | ABC format, melody + chord symbols — the chords make it unusually useful. |
| **thesession.org** | ~40,000 Irish traditional settings | data dumps CC0 / CC BY-SA | Tunes are traditional; check the setting's own terms. |
| **Magenta Groove MIDI (GMD / E-GMD)** | ~13.6 hours of played drums | **CC BY 4.0** | Commercially usable, properly licensed, expressively played. The gold standard for how a dataset should be released. |
| **music21 core corpus** | Bach chorales, ABC folk, Palestrina, trecento | mixed, mostly free | Already parsed; ScaleView measured its chord reader against exactly this. |
| **Anything you commission or write** | whatever you want | yours | See below. |

### Tier 2 — usable with care, keep in a separate split

| Source | Catch |
| --- | --- |
| **IMSLP** | Scores are mostly PD; the *MIDI files* on it vary wildly. Per-file check required. |
| **MAESTRO** (Magenta) | Performances of PD works, but the **dataset is CC BY-NC-SA 4.0**. Not for a commercial product. |
| **GiantMIDI-Piano** | Transcriptions are CC BY 4.0, but many underlying *compositions* are still in copyright. Filter by composer death date. |
| **ASAP**, **(n)ASAP** | Research licences. Read them. |

### Tier 3 — do not use

**Lakh MIDI Dataset**, **POP909**, **MetaMIDI**, and the general run of
scraped `.mid` archives. These are transcriptions of copyrighted songs,
scraped without permission. They are what most published symbolic-music models
train on, and that is a risk those projects have decided to carry. For a
product with your name on it, it is the wrong trade. Lakh in particular is
unavoidably tempting because it is large, clean, and everyone uses it — the
schema's `license` check exists to make including it a deliberate act rather
than a drift.

## The part that actually differentiates you

Public-domain data is classical and folk. **A model trained on Bach chorales
and Irish reels will write Bach chorales and Irish reels.** It will not write
the lo-fi loop or the trap melody someone types into the box, because nothing
in the corpus sounds like that, and no amount of conditioning invents a style
the data does not contain.

There are two answers, and you need both:

1. **Theory carries style; data carries phrasing.** Middaw's generator already
   encodes genre as explicit musical parameters — tempo windows, mode weights,
   progressions, accompaniment figures, swing — in `data/vocab/tags.json`.
   That is why it can write a passable lo-fi loop today with an empty corpus.
   Corpus statistics then improve *how the notes move* within that frame.
2. **Commission original MIDI in the styles you actually want.** Fifty
   well-played 8-bar loops per genre, work-for-hire with written assignment of
   copyright, is a few thousand pounds and is worth more than every scraped
   dataset combined — because it is in the right styles, you own it outright,
   and nobody else has it. Budget for this early; it is the moat.

When commissioning: a written agreement assigning copyright (not just a
licence), the player's name for the `sequencer` field, and a note of what they
were asked to play so it can become the tags.

## Cleaning, before anything is labelled

Run in this order; each step is cheap and each one removes a class of silent
corruption:

1. **Deduplicate.** SHA-256 catches exact copies. Then a *melodic fingerprint*
   — the sequence of pitch intervals of the top line, hashed — catches the same
   tune transposed or re-exported, which is extremely common in scraped sets.
2. **Reject the unusable.** Zero notes, one track of drums only, absurd tempos,
   files that fail to parse. `middaw.corpus.cli ingest` reports these rather
   than crashing.
3. **Detect quantisation.** A file already quantised to a grid and one played
   in are different data. `derived.syncopation` and `derived.swing` expose it.
   Do not quantise everything: the humanisation is the valuable part.
4. **Split into segments.** Generation happens at 4–8 bar scale, so label at
   that scale as well as at file scale (see `LABELLING.md`).
5. **Classify track roles.** GM program numbers plus register and polyphony
   give melody / chords / bass / drums. Do not trust track *names*.
6. **Do not transpose to C on disk.** Transpose at training time if the model
   wants it. Normalising destructively throws away the key distribution, which
   is itself a thing worth learning.

## Record-keeping

`data/corpus/manifest.json` is the record. It is checked by
`python -m middaw.corpus validate`, and the check is deliberately unforgiving:
an entry without complete provenance simply does not enter the training split,
so "we'll sort the licences out later" cannot happen quietly.

Keep a `NOTICE` file listing every source and its licence, generated from the
manifest. Some licences (CC BY, CC BY-SA) require attribution; generating that
file from the data means it cannot fall out of date.
