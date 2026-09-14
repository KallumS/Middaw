# The theory behind Middaw

Everything the generator knows, where it came from, and which parts are built.

This is a working reference, not a textbook. It records what was taken from the
source material, why it matters to a MIDI-first generator, and — marked
throughout — whether Middaw acts on it yet.

| | |
| --- | --- |
| ✅ | implemented |
| ◐ | partly implemented |
| ○ | understood, not built |

## Sources

**Kallum's own studies** — the working vocabulary of this project:
*Chord Theory* (every triad and tetrad possible in 12TET and what each set of
fixed pitches can stand for), *Visualizing the Network of Musical Harmony* (the
fifths-and-thirds lattice), *Key Changes and Modulations*, *The Movement and
Flexibility of Dominant Chords*, *Major Seventh Chords*, *Interesting Chords*,
*Rhythmic Explorations*.

Middaw is a **Western** music-theory system throughout: common-practice tonal
harmony, its modes, and the jazz and popular practice built on top of it. Where
a source reached outside that tradition, the material was left there rather
than imported.

**Robert Hutchinson, *Music Theory for the 21st-Century Classroom*** (University
of Puget Sound, Sept 2025, GNU FDL) — a four-semester college text in 35
chapters. The most systematic source here, and the one the *Chord Theory* notes
already cite. Its harmonic flowchart is now the backbone of Middaw's progression
generator.

**Carl E. Gardner, *Essentials of Music Theory: Elementary*** (Project
Gutenberg) — an elementary primer whose interval-naming rules corroborate the
spelling logic ported from ScaleView.

**The rest of the Gutenberg set** — *The Art of Music* vols 1–7, Krehbiel's
*How to Listen to Music*, Baltzell's *A Complete History of Music*, Engel's
*Musical Myths and Facts*, Rimsky-Korsakov's *Principles of Orchestration*,
Henderson's *The Orchestra and Orchestral Music*, Perry's *Descriptive Analyses
of Piano Works*. These are history, appreciation and orchestration rather than
technique. Rimsky-Korsakov matters later, when Middaw stops being piano-only.

**ScaleView Pro** — see [ARCHITECTURE.md](ARCHITECTURE.md). Ported wholesale
for scales, key-aware spelling and chord naming.

---

## 1. Pitch, spelling and enharmonics

**An interval's name comes from how many letters it spans, not how many
semitones.** C to D is a second whatever accidentals are attached. That is why a
scale degree carries a *letter* as well as an interval, and why Gb major reads
Gb Ab Bb Cb Db Eb F. ✅ `middaw/scaleview.py`

**Enharmonic equivalents are not the same note.** F# and Gb are one pitch on a
keyboard and two different relationships to a tonic: a bright lydian augmented
fourth, or a dark locrian diminished fifth. 12TET collapses them; the ear does
not. The practical consequences Middaw acts on:

- A chord's spelling should say where it is going. `#IV` in lydian, `bV` in
  locrian — the degree decides, never the semitone count. ✅ `roman_for_degree`
- `C7(#9)` is usually a `C7(b10)`: the added note is a minor third, not a raised
  second. The common name is a shortcut, not an analysis. ○
- A dominant seventh and an augmented sixth chord are the same four pitches with
  different resolutions. ○

**Roman numeral accidentals are measured against the major scale, always.** That
is why `bVII` is the subtonic in both C major and C minor, and why `V7` in a
minor key carries a raised leading tone. ✅ `middaw/theory.py`

**Chord symbols never use double accidentals**, however the key spells the note:
A# harmonic minor spells its sixth degree Gx, but a chord built there is still
called Adim. ✅ ported from ScaleView, tested

## 2. Scales and modes

**Seven church modes**, brightest to darkest: Lydian, Ionian, Mixolydian,
Dorian, Aeolian, Phrygian, Locrian. Moving one step to the right on that axis is
the same note-change as modulating up a fifth — it brightens. ◐ the modes are
there; the brightness axis is not wired to "bright"/"dark" prompts yet

**Locrian is a theoretical mode, not a key.** Its tonic triad is diminished, so
there is no perfect fifth above the tonic to anchor it; the "tonic" chord wants
to resolve away rather than sit still. Western practice uses locrian as a
*scale* — what you play over a iiø7 — not as a home. Middaw could previously
pick it as a tonic mode. ✅ now excluded

**The scale inventory.** Middaw ships eighteen, in the three groups Hutchinson
sorts them into:

- **Classical**: major, natural minor, harmonic minor, melodic minor.
- **Modes**: ionian, dorian, phrygian, lydian, mixolydian, aeolian, locrian.
- **Jazz and synthetic**: major and minor pentatonic, major and minor blues,
  whole tone, and the two octatonic (diminished) scales, whole-half and
  half-whole.

The hybrid modes jazz uses — lydian dominant, mixolydian b2, lydian
augmented, altered — are rotations of melodic and harmonic minor, so they come
free from the scales already present. ○ naming them so a prompt can ask for
one by name is not done

**Reduced scales borrow their harmony from a parent.** Pentatonic and blues
scales cannot be stacked in thirds; use the parent seven-note scale for chords.
✅ `PARENT_SCALE`

**The blues scale** is the minor pentatonic with an added note between the 4
and the 5. Its b3, b5 and b7 are the "blue notes" — not chord tones of a major
triad or a dominant seventh, which is exactly why they colour the harmony
rather than belong to it.

**"Faux" chords.** In C harmonic major the 3, b6 and 7 look like an E major
triad, but the b6 sits an augmented second from the 3, not a major third. The
ear notices. Checking pitch-class membership is not enough; interval spelling
has to work too. ◐ `progression_fit` still checks membership only

## 3. Chords

**Read chords, do not match them.** Work out the third, fifth and seventh, then
describe everything above them. A 62-pattern lookup table names 23.9% of all
17,688 three-to-seven-note voicings correctly; reading the intervals names
100%. ✅ `middaw/scaleview.py`

Counting what exists in 12TET: **19 unique triads, 43 unique tetrads, 66
pentads**. One fully symmetrical triad (augmented), one fully symmetrical tetrad
(diminished seventh), two partly symmetrical pairs (7b5 and sus#4(b9)).

Practical rules worth encoding:

- **The fifth is the first note to drop.** It is implied by the root, so
  incomplete voicings are normal and a "no5" chord barely changes function. ◐
- **A missing third has to be said out loud** — `maj7b5(no3)`, not silence. ✅
- **The natural 11 clashes with a major third**; omit it or bracket it. ○
- **Two notes are an interval, not a chord**, and only the bare fifth has a name
  of its own. ✅
- **Past seven notes there is no chord left to find, only a cluster.** ✅
- **All chords are each other in disguise.** G Bb D F# is Gm∆7; put F# at the
  bottom and it starts to sound like F#+(b9). Voicing changes function. ○

## 4. Harmonic function — the backbone

Hutchinson uses **four** functions, not the usual three, and a flowchart:

```
   Tonic  ──►  Tonic Prolongation  ──►  Pre-Dominant  ──►  Dominant  ──►  Tonic
    I              vi, iii                  IV, ii            V, vii°         I
    └──────────────────────────────────────────────────────────────┘
            (the tonic may progress directly to any function)
```

- **Tonic** (I) — stable, demands nothing, may go anywhere.
- **Tonic prolongation** (vi, iii) — the chords sharing *two* common tones with
  the tonic triad. They follow the tonic and lead to pre-dominant.
- **Pre-dominant** (IV, ii) — lead to dominant.
- **Dominant** (V, vii°) — lead to tonic.

Exceptions, and they matter:

- **Plagal cadence** IV–I and **deceptive cadence** V–vi sidestep the flowchart.
  When V goes to vi, the vi is tonic prolongation.
- **I/5th (the cadential six-four) has dominant function** when it resolves to V.
- **In minor the subtonic VII has exactly one function: to progress to III.**

✅ implemented in `middaw/functional.py`, with the separation of tonic
prolongation from tonic — which is what stops vi resolving straight back to I.

**Harmonic rhythm** — how long each chord lasts — is an independent variable.
Whole-note harmonic rhythm and half-note harmonic rhythm are different music
over the same progression. ◐ Middaw is fixed at one chord per bar

## 5. Cadences

| Cadence | Chords | Conclusive? |
| --- | --- | --- |
| Perfect authentic (PAC) | V–I, both root position, 1̂ on top | most |
| Imperfect authentic (IAC) | V–I otherwise | yes |
| Plagal (PC) | IV–I | yes |
| Deceptive (DC) | V–vi | no |
| Half (HC) | ends on V | no |

Conclusive cadences end on the tonic. This distinction is what builds periods:
a phrase ending less conclusively is answered by one ending more conclusively.

✅ `middaw/cadence.py`. Every section is given a cadence before its harmony is
written, and `generate_progression` builds backwards from it, so the ending is
the thing the phrase was designed around rather than whatever it happened to
reach. The closing chords are protected from chromatic decoration. A PAC also
puts the tonic in the melody's top voice, which is the part of the definition
most generators quietly skip.

A minor key borrows a major V at a cadence; a *modal* key does not. Raising
dorian's flat seventh to make a leading tone turns it into minor, which is the
opposite of what was asked for.

## 6. Chromatic harmony

**Secondary dominants.** Every chord in a key has its own dominant. Five have
both a diatonic root and a diatonic target in a major key: I7 (V7/IV), II7
(V7/V), III7 (V7/vi), VI7 (V7/ii), VII7 (V7/iii). ✅

**Substitute dominants.** Two dominant sevenths a tritone apart share their
guide tones, so either can replace the other. SubV7/x resolves *down a
semitone* into x. ✅

**The backdoor dominant** bVII7 resolves *up a whole step* to the tonic. ✅

**Secondary diminished.** vii°7/x, the leading-tone diminished seventh. Every
fully diminished seventh is four chords in one; lower any of its notes a
semitone and you get a dominant seventh — the Barry Harris "family of
dominants". ✅ generated; ○ the family relationship is not exploited

**Related II chords.** A dominant is usually preceded by the chord a perfect
fifth above it, so roots fall by fifths. It belongs to the *target's* key, not
the home key — the ii of F minor is Gø7, not Gm7 — so it is often borrowed. ✅

**Mode mixture** — borrowing from the parallel minor during a major passage:
bIII, bVI, bVII, iv, ii°. The reverse is rare; the one common case is the
**Picardy third**, a major tonic ending a minor piece. ○

**The Neapolitan** bII (usually bII6) — pre-dominant function. ○

**Augmented sixth chords** — Italian, French, German — pre-dominant chords
approaching V from a semitone above and below. Stacked in thirds they contain a
**diminished third**, which no other chord does; that is how you recognise one.
○

**Altered dominants.** A dominant seventh is typically altered (b5/#5, b9/#9)
when it has dominant function — when its root falls a fifth — and left
unaltered when it has tonic function, like the first chord of a blues. ○

## 7. Melody

**Motive → fragment → subphrase → phrase.** A motive is the smallest
identifiable idea (two to seven notes); a subphrase is usually two bars; a
phrase is usually four. ◐ Middaw builds motives and varies them, and sections
sharing a letter share a motif so a return is heard as a return; it still has
no subphrase model.

**Seven ways to alter a motive** — the whole toolkit of melodic development:

| Alteration | What it does | Built? |
| --- | --- | --- |
| Inversion | mirrored; *tonal* (in the scale) or *real* (exact intervals) | ✅ tonal |
| Intervallic change | rhythm intact, intervals adjusted to fit the harmony | ✅ |
| Augmentation | every duration doubled | ○ |
| Diminution | every duration halved | ○ |
| Rhythmic change | some but not all durations varied | ✅ |
| Ornamentation | decorate with non-chord tones | ✅ |
| Extension | material added on repetition | ○ |
| Retrograde | order of notes reversed | ○ |

**Non-chord tones** — classified by how they are approached and left. A
non-chord tone is not a kind of pitch; it is a *relationship* between three
notes, which is why `middaw/embellish.py` decides them as a pass over a
finished chord-tone line rather than while the line is being written:

| Type | Approached by | Left by | Built? |
| --- | --- | --- | --- |
| Passing tone | step | step, same direction | ✅ |
| Neighbor tone | step | step, opposite direction | ✅ |
| Appoggiatura | leap | step | ✅ |
| Escape tone | step | leap, opposite direction | ✅ |
| Double neighbor | upper and lower neighbor before returning | | ○ |
| Anticipation | step | same note | ✅ |
| Pedal point | same note | same note | ○ |
| Suspension | same note | step **down** | ✅ |
| Retardation | same note | step **up** | ✅ |

Qualifiers: accented (on the beat) / unaccented; chromatic; metrical /
sub-metrical / super-metrical. Suspensions are numbered by the interval above
the bass and its resolution: 9-8, 7-6, 4-3, 2-3, 6-5. ◐ Middaw writes accented
and unaccented decoration and reports which; it does not yet write chromatic
decoration or number its suspensions.

**Rules of melody** (from Bach's 371 chorales):

1. Mostly stepwise motion.
2. Leaps larger than a fourth, and any diminished leap, change direction after.
3. Consecutive leaps should outline a triad.

✅ rules 1 and 2; ○ rule 3

## 8. Rhythm

**Swing is a percentage**, not a vague setting — where the offbeat sits between
two beats:

| Feel | Ratio | % |
| --- | --- | --- |
| straight | 1/2 | 50 |
| septuplet | 4/7 | 57 |
| quintuplet | 3/5 | 60 |
| triplet ("swung") | 2/3 | 66 |
| sixteenth | 3/4 | 75 |
| heavy quintuplet | 4/5 | 80 |

◐ Middaw has a swing float; it should carry these named values

**Subdivision groupings.** Sixteen 16th notes in a bar need not be 4+4+4+4.
Real music groups them 5+5+5+... , 3+3+4+3+3, 6+5+5, 4+5+4+5+4+5+5. This is
where a great deal of rhythmic identity lives and Middaw has none of it. ○

**The 3+3+2 (tresillo) and the 3–2 son clave** are everywhere in popular music —
habanera, reggaeton, "Eye of the Tiger", "Shape of You", "All of Me". Also
3+3+4+3+3. ○

**Metric modulation** — two kinds: the tempo changes while the subdivision
spacing stays constant, or the tempo stays while the subdivision changes. ○

**Dilla time** — parts deliberately off the grid *in different directions*: kick
ahead, snare behind. Not random jitter, which is what Middaw does now. ○

**Odd meters are felt as groupings**, not as counts: 7/8 is 3+2+2 or 2+2+3;
9/8 is often 2+2+2+3; 15/8 is 3+3+3+3+3 or 2+4+2+4+3. ○

**Polyrhythm** (two rhythms in the same span, 3:4) versus **polymeter** (two
meters at the same tempo that do not line up). ○

## 9. Phrase and form

**Phrase lengths.** Four bars is the norm; eight is next. Five, six and seven
happen; three is rare. Subphrases are usually two bars.

**The sentence** — a phrase whose melody is a motive, then that motive repeated
or sequenced, then related or unrelated material leading to a cadence. Typically
1 + 1 + 2 bars.

**The period** — two or more phrases where the last ends more conclusively than
the first. The first is the *antecedent*, the last the *consequent*. Parallel if
the phrases begin alike, contrasting if not.

**Phrases in combination** — the whole grammar on one table:

| Phrases | Form | Melody | Cadences |
| --- | --- | --- | --- |
| 2 | Parallel period | a a′ | less then more conclusive |
| 2 | Contrasting period | a b | less then more conclusive |
| 2 | Phrase group | a a′ | ends HC |
| 2 | Phrase chain | a b | ends HC |
| 2 | Repeated phrase | a a | same cadence twice |
| 3 | Asymmetrical period | a a b / a b b | ends most conclusive |
| 4 | Double period | a b a b′ / a b a c | antecedent group, consequent group |

An **elision** joins phrases by making one bar serve as both the last of one and
the first of the next.

**Form in popular music** — sections of 4, 8, 12 or 16 bars:

- **Verse–chorus**, optionally with pre-chorus, post-chorus and bridge. *Simple*
  if verse and chorus share a progression, *contrasting* if not.
- **AABA**, 8 bars per section, 32 total. The B section is the bridge or
  "middle eight".
- **ABAC**, 32 bars.
- **12-bar blues**.

Sections are **harmonically open** (not ending on the tonic) or **closed**.
Sections leading into a chorus are usually open.

**Classical forms** — binary and ternary, *sectional* (the A section ends on the
tonic) or *continuous* (it does not). **Binary principle**: the first section
modulates away (major I→V, minor i→III or v) and the second modulates back.
Rounded binary brings the opening material back after a contrasting phrase.
Sonata form and rondo build on these.

✅ **Built.** `middaw/form.py` carries a catalogue of thirteen forms — motif,
period, strophic (AAA), binary (AB), repeated binary (AABB), ternary (ABA),
AABA, rondo (ABACA), seven-part rondo (ABACABA), medley (ABCD),
through-composed, sonata, and fugue — chosen from the prompt, else from the
style, else from the length. The prompt's length word sets a *target*; the form
sets the real length, because a five-section rondo is five sections long.

Every section gets a role (refrain, episode, bridge, development, subject,
answer) and a cadence. Sections whose job is to lead somewhere stop on the
dominant; the first of a pair asks and its twin answers; the last section gets
the most conclusive ending there is. Sections sharing a letter are the *same
music re-ended* — only the closing chords change — so a refrain that opens and
the same refrain that closes are recognisably one tune. In a fugue the answer
enters a fifth above the subject.

Still missing: sentences as a melodic construction, harmonically open and
closed sections as an explicit choice, elisions, and the 12-bar blues as a form
rather than a progression.

## 10. Texture and accompaniment

Texture has a **vertical** dimension (how many voices) and a **horizontal** one
(how fast the prevailing rhythmic value is). Both are worth controlling
separately.

Accompanimental figures worth having, from Hutchinson's survey:

| Figure | Built? |
| --- | --- |
| Chorale / homorhythmic — a chord per melody note | ✅ `block` |
| Arpeggios over a bass in octaves | ✅ |
| Alberti bass — low, high, middle, high | ✅ |
| Repeated eighth-note chords | ✅ |
| Afterbeats — repeated chords after the downbeat | ✅ `offbeat` |
| Offbeats — chords on upbeats only (polka, reggae) | ✅ |
| "1 (2) &" — chord on beat 1 and the upbeat after 2 | ○ |
| 3–2 son clave, tresillo (3+3+2) | ○ |
| Distinctive bass riffs | ○ |
| **Ostinato** — one figure restated over every chord | ✅ `middaw/voices.py` |
| **Arpeggio as its own voice**, not an accompaniment pattern | ✅ |

A **tenth between the bass and the top voice** is what makes arpeggiated
accompaniments sound open rather than muddy. ○

**Creating contrast between sections** varies the "elements of music": melody,
harmony, rhythm, timbre, texture, articulation, dynamics, register. ◐ Middaw
varies harmony, density, register and dynamics between sections; timbre,
articulation and texture are untouched.

## 11. Voice leading

Middaw voices chords naively. The rules it should follow:

- **Avoid parallel fifths and octaves.** Parallel 3rds, 4ths and 6ths are fine;
  2nds and 7ths are not.
- **Doubling**: root position — double the bass; first inversion — do *not*
  double the bass; second inversion — double the bass.
- **Bass moves a 3rd or 6th** — hold two common tones, move one voice by step.
  **A 2nd** — move upper voices contrary to the bass. **A 4th or 5th** — hold
  one common tone, move two by step.
- **Resolve the seventh of a seventh chord down by step.** Always.
- Successive root-position sevenths: alternate complete and incomplete voicings.
- **Spacing**: soprano–alto and alto–tenor within an octave; bass–tenor may be
  wider. Larger gaps belong at the bottom, as in the overtone series.
- Add sevenths to build tension approaching tonic function — most often on
  dominant-function chords.

◐ The countermelody applies two of them: it moves contrary to the melody where
it can, and it refuses parallel fifths and octaves against it. The chord
voicings still ignore doubling, spacing and seventh resolution.

## 12. Modulation

Types, from Kallum's *Key Changes and Modulations*: **direct** (no preparation),
**common-tone**, **common-chord / pivot**, **chromatic**, **sequential**,
**chain** (constant structure moving by fifths), and **parallel / modal
interchange** (same tonic, different mode).

A modulation is only confirmed by a **cadence in the new key** — typically
pre-dominant → dominant → tonic. Tonicization is the same motion without the
cadence; that is the whole difference.

Direction on the circle of fifths has a felt quality: clockwise (up a fifth,
adding sharps) brightens, anticlockwise darkens. Modal interchange behaves the
same way — C dorian to C mixolydian is the same note-change as Bb major to F
major, and brightens.

**Enharmonic modulation** reinterprets a chord that is spelled for one key and
heard in another — a harmonic pun. Diminished sevenths and augmented triads are
the usual pivots, since each is several chords at once.

○ Middaw never changes key.

## 13. Jazz specifics

- **Guide tones are the 3rd and 7th.** In any circle-of-fifths progression
  (ii–V–I, iii–vi–ii–V) they move by step. Tritone substitutes share them. This
  is the basis of a real voicing algorithm. ○
- **Spread voicing**: root, 3rd and 7th lowest, the rest above in 4ths and 5ths.
  **Close voicing**: bass alone in the left hand, four notes close in the right
  with the 3rd or 7th lowest. ○
- Omit the 5th freely; omit the natural 11 over a major third.
- **The turnaround** iii–vi–ii–V replaces a static tonic in the last two bars.
  All four can be made dominant sevenths, then tritone-substituted. ○
- **The bebop scale** is mixolydian with an added natural 7 as a chromatic
  passing tone.
- **Chord–scale relationships**: write the chord tones, fill the gaps, avoiding
  augmented seconds and consecutive half steps. ○

## 14. After 1900

**Impressionism** — modes instead of chromaticism; upper extensions; and
**planing**, moving a whole voicing in parallel, which is precisely the
prohibition of classical voice leading turned into a technique.
**Pandiatonicism** — diatonic notes with no functional obligation.
**Quartal, quintal and secundal** harmony — stacking in 4ths, 5ths or 2nds
instead of 3rds. **Polychords** — two triads at once. **Set theory** — integers
and intervals where there are no chords or scales. **Serialism**. **Minimalism**
— additive process and phasing.

○ None built. Quartal voicings and planing would be cheap and would immediately
widen the range of what Middaw can sound like.

---

## The honest summary

Middaw currently implements, in rough order of confidence: chord spelling and
naming, mode-derived diatonic harmony, the four-function flowchart, secondary
and substitute dominants, related II chords, all five cadences, thirteen forms
with per-section cadence planning, six voices (melody, countermelody, ostinato,
arpeggio, chords, bass), motif-based melody with tonal inversion, seven kinds
of non-chord tone applied and then re-verified, a rhythm-cell vocabulary, and
twelve accompaniment figures.

The biggest gaps, in the order they would most improve the output:

1. **Subdivision groupings and clave** — where rhythmic identity actually lives.
2. **Voice leading for the chords** — doubling, spacing, guide tones, and
   resolving the seventh down by step. The countermelody already avoids
   parallel perfect intervals; nothing else does.
3. **Modulation** — the app cannot change key at all, so a sonata exposition
   cannot really go to the dominant and a binary form cannot really come back.
4. **Sentences and elisions** — the melodic side of phrase construction.
5. **Chromatic decoration** — every non-chord tone Middaw writes is diatonic,
   so it decorates but never leans.
