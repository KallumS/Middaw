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
| **Nottingham Music Database** | ~1,200 British/Irish folk tunes | traditional, freely distributed | ABC format, melody + chord symbols — the chords make it unusually useful. |
| **thesession.org** | ~40,000 Irish traditional settings | data dumps CC0 / CC BY-SA | Tunes are traditional; check the setting's own terms. |
| **Magenta Groove MIDI (GMD / E-GMD)** | ~13.6 hours of played drums | **CC BY 4.0** | Commercially usable, properly licensed, expressively played. The gold standard for how a dataset should be released. |
| **Anything you commission or write** | whatever you want | yours | See below. |

### Tier 2 — usable with care, keep in a separate split

| Source | Catch |
| --- | --- |
| **IMSLP** | Scores are mostly PD; the *MIDI files* on it vary wildly. Per-file check required. |
| **MAESTRO** (Magenta) | Performances of PD works, but the **dataset is CC BY-NC-SA 4.0**. Not for a commercial product. |
| **GiantMIDI-Piano** | Transcriptions are CC BY 4.0, but many underlying *compositions* are still in copyright. Filter by composer death date. |
| **ASAP**, **(n)ASAP** | Research licences. Read them. |
| **music21 core corpus** | The compositions are almost all out of US copyright; the *encodings* are licensed to music21, and its own licence file warns of commercial restrictions. Per-repertory clearance needed — see below. |
| **Essen Folksong Collection** | ~8,500 melodies as shipped with music21, and explicitly **non-commercial**: the encodings are licensed to music21, not onward. The wider ESAC database's status is described by its own maintainers as unclear. |
| **Ryan's Mammoth Collection** (1883) | The tunes are long out of copyright; the ABC encodings shipped with music21 carry no stated terms of their own. Worth chasing to the original ABC transcribers, since a cleared fiddle repertory is genuinely useful to us. |

### Tier 3 — do not use

**Lakh MIDI Dataset**, **POP909**, **MetaMIDI**, and the general run of
scraped `.mid` archives. These are transcriptions of copyrighted songs,
scraped without permission. They are what most published symbolic-music models
train on, and that is a risk those projects have decided to carry. For a
product with your name on it, it is the wrong trade. Lakh in particular is
unavoidably tempting because it is large, clean, and everyone uses it — the
schema's `license` check exists to make including it a deliberate act rather
than a drift.

## The music21 corpus, checked

It comes up every time, so here is what is actually in it and what its licence
actually says. Counted from the repository at `cuthbertLab/music21`, and quoted
from `music21/corpus/license.txt`.

**The software is BSD-3-Clause. The corpus is not covered by that.** Its own
licence file says the encodings are "distributed with the permission of the
encoders" and that:

> Some encodings included in the corpus may not be used for commercial uses or
> have other restrictions … The encodings may be under copyright but have been
> licensed for use, though there may be restrictions on commercial use.

That is the two-clearance problem again, and it lands on the second clearance.
The compositions are fine — Palestrina, Bach, a fiddle collection printed in
1883. The *encodings* are licensed **to music21**, and that permission does not
travel to us. Only one repertory carries its own licence file, and it is the
largest one:

> [Essen] … Prof. AMU Dr. Habil. Ewa Dahlig-Turek, who has given permission for
> **non-commercial** distribution and use of these files in music21. … The
> files distributed with music21 are ABC encodings, created by Seymour Schlien,
> and distributed with music21 by his permission.

So Essen is out for a commercial product as it stands — though asking those two
people directly is a small and realistic thing to do, and is the correct route
if we want it.

**What is in there**, by weight rather than by file count, since the ABC files
are collections:

| Repertory | Size | What it is good for |
| --- | --- | --- |
| Essen folksong | 8,514 tunes in 31 ABC files (1,224 of them Chinese, outside our Western scope) | melodic intervals, contour, phrase length — monophonic |
| Palestrina | 1,318 `**kern` files | Renaissance counterpoint, modal cadences |
| O'Neill's *Music of Ireland* (1850 tunes) | ~1,800 tunes in 39 ABC files | celtic, and the jig/reel rhythmic cells |
| Ryan's Mammoth Collection (1883) | 1,059 ABC tunes | bluegrass, celtic, old-time fiddle repertoire |
| Bach chorales | 408 MusicXML | **four-part writing** — our exact texture — plus cadences, non-chord tones, voice leading |
| Bach + Monteverdi analyses | 68 RomanText files | human harmonic analyses: ground truth for testing ours |
| Aird's *Airs* (1782) | 6 books of ABC | Scottish and English airs |
| Trecento, Monteverdi, Josquin, Ciconia, Lusitano | ~260 files | early music |
| Beethoven 26, Mozart 16, Haydn 9, Schumann 12, others 1–2 each | ~80 files | not enough of any one composer to calibrate anything |

Two things follow from that table. The first is that it is **not** the
symphonic classical archive people assume — there is exactly one Chopin file
and one Schubert. It is overwhelmingly **folk melody and Renaissance
polyphony**. The second is that the 68 RomanText analyses are the most
interesting thing in it for us: a human analyst's roman numerals for music we
also have the notes for, which is a real test set for `middaw/corpus/analyse.py`
and costs nothing to use, because nothing derived from it is shipped.

What it cannot give us at all: anything after about 1900. No swing, no
backbeat, no comping, no groove, no extended harmony, no production. Those are
exactly the styles whose constants in `data/vocab/tags.json` are currently set
by hand — so this corpus calibrates the half of the vocabulary that is already
strongest, and leaves the modern half where it is.

**The formats are notation, not MIDI** — `**kern`, ABC and MusicXML. That is a
feature for measurement, because barlines, key signatures and separated voices
are all still there, which MIDI loses. It needs a converter, and using music21
itself offline to do the conversion is fine: the no-dependency rule is about
what Middaw *ships*, not about what a `tools/` script uses to prepare data.

## MusicXML corpora, checked

Notation beats MIDI for everything except playback: barlines, key signatures,
separated voices and — where somebody has written one — a harmonic analysis
lined up with the notes. These are the ones worth knowing about, with the
licence as their own files state it rather than as the internet remembers it.
Counted from the repositories, October 2026.

| Corpus | Size | Licence | Use |
| --- | --- | --- | --- |
| **[OpenScore Lieder](https://github.com/OpenScore/Lieder)** | 1,462 `.mxl` songs, 100+ nineteenth-century composers | **CC0 1.0** — the repository ships the CC0 legal code | The cleanest thing available. Voice line plus piano, so the melody is separable |
| **[OpenScore String Quartets](https://github.com/OpenScore/StringQuartets)** | 196 `.mxl` movements | **CC0 1.0** | Four independent parts — our exact texture |
| **[When in Rome](https://github.com/MarkGotham/When-in-Rome)** | 761 scores, 1,494 human analyses, 535 of them lined up with a score | **CC BY-SA 4.0** for new content; analyses converted from elsewhere keep their original licences, which "vary" | Ground truth for harmonic analysis, thirty times what the music21 chorales gave us |
| **[PDMX](https://github.com/pnlong/PDMX)** | 250,000+ MusicXML scraped from MuseScore's public-domain-tagged uploads | code MIT; the scores are whatever their uploaders claimed | See below |
| **[Bach 370 chorales](https://github.com/craigsapp/bach-370-chorales)** (Craig Sapp) | 370 `**kern` chorales | **CC BY-NC-SA 4.0** — non-commercial | Measurement only |
| **[DCML corpora](https://github.com/DCMLab)** (Beethoven quartets, Mozart sonatas, and more) | annotated scores with harmony labels | **CC BY-NC-SA 4.0** — non-commercial | Measurement only |

**The OpenScore corpora are the find.** CC0 is a waiver, not a licence with
conditions: the encoders gave up their rights in the encodings, and the
compositions are nineteenth-century. Both clearances, settled, in the format
that keeps the most information. They ask to be credited and it costs nothing
to do it.

**When in Rome is the measuring stick.** 535 scores with a human analyst's
roman numerals beside them, against the eighteen the music21 chorales gave us.
Note two things when using it: `analysis_automatic.rntxt` is a machine's
reading and must never be used as ground truth — measuring against another
model tells you how alike two guesses are, not whether either is right — and
the licence is share-alike, which is fine for measuring (nothing is
distributed) and needs thought before anything derived from it ships.

**PDMX deserves its own paragraph**, because it is the one that looks like it
solves everything. It is a careful piece of work — the paper is explicitly a
response to the Suno and Udio lawsuits — and its own README reports that the
copyright metadata on the MuseScore website disagrees with the metadata inside
the files for 12.29% of them (31,221 songs), recommending the
`no_license_conflict` subset. The deeper problem is one no filtering can fix:
"public domain" there is *the uploader's claim*, and a user who transcribes a
2019 pop song and ticks public domain has not made the composition public
domain. For research that is a reasonable risk to carry. For a product with
your name on it, it is the Lakh problem with better paperwork.

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
