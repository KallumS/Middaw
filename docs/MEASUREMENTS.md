# What the corpora say

A log of every measurement taken against music Middaw did not write, with the
corpus, the date and the number. `python3 -m middaw.corpus measure <folder>`
produces all of it; `docs/APPROACH.md` says why this matters more than any
figure the generator produces about itself, and `docs/DATASET.md` says what
each corpus permits.

**Nothing here is ingested.** The tool reports numbers about a folder and
copies nothing, which is what makes the non-commercial corpora usable: measuring
is not redistributing. Only the CC0 corpora may inform a constant that ships.

## The corpora, as measured

Run on 14 September 2026, against the harness as it stood at that commit.

| Corpus | Scores | Licence | May inform a shipped constant? |
| --- | --- | --- | --- |
| [OpenScore Lieder](https://github.com/OpenScore/Lieder) | 1,462 MusicXML songs | CC0 | yes |
| [OpenScore String Quartets](https://github.com/OpenScore/StringQuartets) | 196 MusicXML movements | CC0 | yes |
| [When in Rome](https://github.com/MarkGotham/When-in-Rome) | 762 scores, 535 with a human analysis | CC BY-SA (converted analyses keep their own) | measurement only |
| [Bach 370 chorales](https://github.com/craigsapp/bach-370-chorales) (Sapp) | 370 `**kern` | CC BY-NC-SA | measurement only |
| music21 Bach chorales | 413 MusicXML, 18 with an analysis | encodings licensed to music21 | measurement only |

The **DCML corpora** are in here too, without a second parser: When in Rome
carries their Beethoven quartets, Mozart sonatas and Chopin mazurkas converted
to RomanText, under the original CC BY-NC-SA. Measurement only, which is all we
do with them.

### Key detection

| Corpus | States a key | Tonic and mode | Tonic | Signature only | Tonic inside the written collection |
| --- | --- | --- | --- | --- | --- |
| Bach chorales (Sapp) | 322 | **87.0%** | 92.5% | 48 | 97.9% |
| Bach chorales (music21) | 412 | 75.0% | 80.3% | 1 | — |
| When in Rome | 535 | 53.3% | 62.4% | 226 | 99.6% |
| OpenScore Lieder | 5 | — | — | 1,457 | 98.8% |
| OpenScore String Quartets | 0 | — | — | 196 | 98.0% |

Read those last two columns together with the first: **the collection is almost
always right and the tonic inside it is where we lose.** 98–99.6% of the time
the key we name is built from the notes the signature says are there; we then
pick the wrong degree of it often enough to drop to 53% on songs. That is a
diagnosis rather than a score, and it points at the second half of `detect_key`,
not the first.

Two cautions that the corpora themselves supply:

- **The ground truth is only so good.** 154 chorales appear in both the Sapp
  and music21 editions, and the two disagree about the key of six of them —
  four per cent — nearly all major against its relative minor. No measurement
  of this kind is more precise than that.
- **A key signature is not a key.** 1,457 of the 1,462 Lieder scores state a
  signature and never say major or minor, because that is what MuseScore's
  MusicXML export writes. Reading that as major invents a ground truth and then
  marks correct answers wrong against it — which is exactly what the first run
  of this tool did, reporting 53.6% for a question it had no right to ask. The
  harness now separates the two and asks each the question it can answer.

### Harmonic analysis

Measured on the analyst's own segmentation, so the only question is whether we
name the same chord over the same span.

| Corpus | Analyses | Chords | Same root | Root and quality | Numerals we cannot express |
| --- | --- | --- | --- | --- | --- |
| When in Rome | 535 | 52,685 | **62.7%** | 56.6% | 72 (0.1%) |
| music21 chorales | 18 | 1,041 | 80.5% | 78.7% | 0 |

Eighteen points between four voices in crotchets and an arpeggiated piano
accompaniment under a modulating song. The chorale figure is the ceiling; the
other is the number to quote.

### Melody

The top line of a piano staff is not a melody, so this is measured only where a
score has a part that carries a single line — a voice, a first violin.

| | Chorales (Sapp) | Quartets | Lieder | Middaw |
| --- | --- | --- | --- | --- |
| lines measured | 370 | 196 | 1,404 | 60 per style |
| stepwise | 70.4% | 50.9% | 47.0% | 49–60% |
| repeated note | 15.0% | 12.5% | 21.0% | 8–19% |
| leap turns back | 76.7% | 81.1% | 89.8% | 75–81% |

**There is no single right amount of stepwise motion.** A chorale steps 70% of
the time; a song steps 47% and repeats a note 21%, because it is setting
syllables; a quartet's first violin sits between them. Middaw's figure moves
with the style too, so it is not wrong everywhere — it is unmeasured
everywhere, which is a different problem and the one a corpus fixes.

**Turning back after a leap is the one real gap.** Every repertoire measured
does it more reliably than we do, and the songs do it 90% of the time against
our 77%. That is rule 2 in `docs/THEORY.md`, marked implemented, and it is
implemented at the wrong strength.

### Setting the dials from it

`middaw/chance.py` holds the generator's probabilities by name, and four of the
measurements above are now the defaults for the styles they describe — hymn
from the chorales, classical from the quartets, romantic era and ballad from
the Lieder. What moved, measured before and after:

| Interval distribution distance from real music | before | after |
| --- | --- | --- |
| hymn vs Bach chorales | 0.206 | **0.173** |
| romantic era song vs Lieder | 0.164 | **0.137** |
| classical piece vs string quartets | 0.110 | **0.108** |

The bass dial came from the same place: over 52,570 analysed chords the real
bass is the root 44.4% of the time, the third 20.9%, the fifth 14.2%, and
something outside the chord for the remaining 20.5% — a passing note, usually.
Counting only the times it is on a chord tone at all, which is the only choice
our dial makes, that is 56% root. Middaw had it at 70% by assumption.

**The dial is not the outcome.** A melody told to step 70% of the time comes
out at 55%, because chord-tone snapping, the register window and the cadence
all act after the dice. So the dials move the output in the right direction
without landing on the number, and the output is what gets measured.

### The kit

From the Groove MIDI Dataset (CC BY 4.0), 491 beats, 470,000 hits, measured
with `tools/measure_groove.py`. These are the numbers `middaw/drums.py` uses.

| | hits | velocity | on the beat | off it | scatter, in 16ths |
| --- | --- | --- | --- | --- | --- |
| snare | 116,465 | 67.7 | 80.5 | 60.9 | ±0.21 |
| kick | 84,399 | 58.4 | 64.3 | 52.9 | ±0.19 |
| hi-hat | 64,239 | 69.1 | 81.3 | 63.1 | ±0.15 |
| pedal hat | 49,812 | 65.5 | 62.9 | 67.2 | ±0.19 |
| ride | 43,862 | 71.9 | 78.1 | 68.5 | ±0.17 |
| tom | 26,142 | 87.1 | 91.1 | 85.3 | ±0.19 |
| open hat | 13,811 | 85.1 | 89.5 | 83.0 | ±0.17 |
| crash | 3,513 | 77.3 | 86.0 | 68.1 | ±0.18 |

**A hit off the beat is about 0.78 of one on it.** That single ratio is most of
what separates a played bar from a programmed one, and it holds across the kit.

Ghosted snares — the share played below velocity 45 — are a style constant and
are now set per style: reggae 57%, funk and latin 47%, jazz 44%, soul 39%,
hip-hop 34%, rock 32%, punk and afrobeat 28%, pop 24%, gospel 21%.

**The one we nearly published was wrong.** The first run said every drummer on
the record played 0.05 of a sixteenth *early* — every instrument, every style,
the same amount. A result that tidy is almost always the measurement's own
fault, and it was: a recorded take does not begin on beat zero, and nothing had
found the grid before measuring distance from it. `grid_phase` now finds the
sixteenth grid per performance and `beat_offset` finds which sixteenth is the
beat. Aligned, the rush disappears — +0.008 of a sixteenth for a snare, −0.001
for a kick — and what is left is the scatter, which is real and is what the
generator uses. The third time this project has been caught by its own reader.

Swing stayed unpublished. Measured off the ride and hi-hat it needs beats
played *in two* to say anything, and after filtering for those there are 56
usable beats of jazz — too few to set a constant from, and the styles' existing
swing values stand until there is more.

### What the corpora found in our code

Each of these was a bug in the *reader*, found because a measurement collapsed:

1. **156 of the 410 music21 chorales mark the soprano minor and the lower three
   major**, on the same signature. Reading every part and keeping the last
   called a third of them major, which read as key detection failing at 45%.
2. **Every tied note in every `**kern` file was being dropped.** The duration
   pattern was anchored to the front of the token, and a tie-start is written
   `[2a`, so it parsed as no duration at all. Fixing it moved the Sapp
   chorales from 70.0% to 87.0%.
3. **MuseScore exports state no mode**, as above.
4. **The bass overlapped itself by up to 1.8 beats.** Any chord lasting two
   beats or more in a dense style played its root for 95% of the span and then
   its fifth from halfway, both sounding at once. A bass line is one note at a
   time; it is now trimmed to the next onset, after humanising rather than
   before.

Which is the standing lesson: when a number collapses, the reader is the first
suspect, not the analyser.
