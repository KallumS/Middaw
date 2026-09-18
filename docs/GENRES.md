# Genres: what each one is, and how its notes are formulated

This is the reasoning behind `data/vocab/tags.json`. The JSON is the record the
code reads; this file is the record of *why* each number is what it is, so the
next person to change a tempo band or a mode weight knows what they are
arguing with.

It was written against a list of 909 genre names covering 45 families — every
name in that list is accounted for below, either by a style Middaw generates
or by an explicit reason it does not.

Two things worth saying before the detail:

- **A genre is not a sound here, it is a set of note-formation rules.** Middaw
  writes notes and nothing else: no drums, no timbre, no production. Where a
  genre's identity lives entirely in its sound — noise, shoegaze, musique
  concrète, most of glitch — there is nothing for Middaw to write, and saying
  so is more useful than faking it.
- **Most genres share their machinery.** A twelve-bar is a twelve-bar in
  boogie-woogie, jump blues, rockabilly and zydeco; a ii–V–I is the same object
  in bebop, city pop and lounge. [The shared devices](#the-shared-devices)
  below are listed once, and each style's entry says which of them it uses and
  what it does differently. That is what "similarities and idiosyncrasies"
  means in practice.

## How a style is described

Each genre entry in `data/vocab/tags.json` sets the same fourteen dials, and
between them they decide every note:

| Field | What it decides |
| --- | --- |
| `tempo` | the range a tempo is drawn from when the prompt gives no bpm |
| `modes` | weighted scale choice — this picks the notes the melody may use at all |
| `meters` | weighted time signature |
| `progressions` | the style's stock loops, used when the grammar is not |
| `functional` | how often harmony is *written* by the chord-function grammar (`middaw/functional.py`) rather than taken from that list. High for jazz and hymnody, near zero for a funk vamp, because a one-chord vamp is not a weak progression — it is a refusal to have one |
| `chromaticism` | appetite for secondary and substitute dominants |
| `extensions` | how often chords carry sevenths and above |
| `patterns` | weighted accompaniment figure (`middaw/accompaniment.py`) |
| `density` | how many notes per pulse the rhythm generator asks for |
| `swing` | where the offbeat sits, as a fraction between two beats |
| `register` | octave offset, in scale steps of the voicing window |
| `velocity` | base loudness |
| `ornament` | appetite for non-chord tones (`middaw/embellish.py`) |
| `synonyms` | every word that should reach this style, including sub-genres whose notes are the parent's |
| `chances` | optional: the style's own probabilities (`middaw/chance.py`) — how often the melody steps, skips or repeats, how often the bass takes the root, how often a phrase comes home. Set from measurement or left alone; `docs/MEASUREMENTS.md` says which styles have been measured |

Two more tables live in code rather than data because they name code objects:
`GENRE_FORMS` in `middaw/form.py` (which forms suit a style) and
`GENRE_TREATMENT` in `middaw/prompt.py` (how the style plays its harmony part —
comped chords, a repeating figure or a broken chord). `PLAGAL_GENRES` marks the
styles that end IV–I rather than V–I.

Every generation is the same five parts — melody, countermelody, harmony, bass
and drums (`middaw/parts.py`) — so a style never gets more or fewer lines than
another. What varies is what they *do*. Which beat a style plays, and whether
it has a drummer at all, is in `data/vocab/drums.json`; a style missing from
that file is one nobody drums.

**Adding a genre means filling in all of that, and the tests check it.**
`tests/test_vocab.py` asserts every genre is completely described, that its
modes, meters, figures and chord symbols all exist, that each style renders,
and — the one that catches real mistakes — that every mode a style names has at
least one listed progression that actually fits it. A progression that does not
fit is never chosen, so an unfitting list is not a bad list, it is dead data.

## The families, and what Middaw does with each

| Family in the list | Middaw's styles | Notes |
| --- | --- | --- |
| Alternative / Rock | rock, punk, metal, prog rock, surf, rockabilly, grunge→rock | Sub-genres whose difference is distortion and attitude route to the parent |
| Blues | blues, boogie-woogie | Twelve-bar, dominant-seventh harmony, blue notes over it |
| Children's | lullaby | |
| Classical | classical, baroque, romantic era, renaissance, impressionist, hymn | Forms (sonata, concerto, symphony) are handled on the *form* and *length* axes, not as genres |
| Country | country, bluegrass, zydeco | |
| Dance / EDM | house, techno, trance, drum and bass, dubstep, UK garage, disco | Hardcore splinters (gabber, hardstyle, speedcore) route to techno: same notes, faster |
| Easy listening | lounge, new age | |
| Electronic | ambient, chiptune, synthwave, synthpop, vaporwave, trip-hop, minimal | |
| Folk | folk, celtic, klezmer, polka, march | |
| Hip-hop / Rap | trap, boom bap, lofi | |
| Gospel / Inspirational | gospel, hymn | |
| Jazz | jazz, bebop, big band, dixieland, modal jazz, smooth jazz, bossa, ragtime | The one family where sub-genres really do formulate notes differently |
| Latin | salsa, samba, bossa, tango, flamenco, cumbia, reggaeton, bachata, mariachi | |
| Metal | metal | Its twenty-odd splinters share one harmonic language |
| New Age | new age, ambient | |
| Pop | pop, ballad, synthpop, city pop, doo-wop, disco | K-pop and J-pop route to pop: the harmony is Western pop, the identity is production |
| R&B / Soul | rnb, soul, funk, disco | |
| Reggae | reggae, ska | |
| Singer/Songwriter | folk, ballad | |
| Soundtrack | cinematic | |
| Vocal | barbershop, doo-wop | The rest of the family is performance, not note formation |
| World — Africa | afrobeat | |
| World — Caribbean | reggae, ska, calypso→(unmapped) | |
| Anime, Comedy, Commercial, Disney, Fitness, Holiday, Karaoke, Spoken Word | — | Not styles; see [below](#deliberately-not-mapped) |

Of the 909 names in the list, 571 (63%) now reach a style from a prompt. The
rest are accounted for in the last section, and the ones that are real gaps are
named there rather than quietly dropped.

## The styles

### Blues and its descendants

**Blues** — 12-bar I7–IV7–V7, shuffled. The idiosyncrasy that shapes
everything else in this family: the melody is minor-ish (b3, b5) and the
harmony is major-ish (dominant sevenths). Middaw models that explicitly —
`BLUES_MODES` in `middaw/theory.py` lets the blues scales take their harmony
from mixolydian as well as their own parent, and lets a progression over them
be of either tonality. Without that rule a blues-scale melody would refuse an
I7 as "not in the key", which is exactly backwards.

**Boogie-woogie** — the same twelve bars at 150–200, with the left hand
playing eight to the bar. The figure is `broken_octave`; density is at the top of the
range (0.85, shared with bebop and bluegrass) because the ostinato never
stops. The melody is
heavily ornamented (0.45) — this is where blues piano lives.

**Rockabilly** — the twelve-bar again, swung a little less (0.28), major-third
melodies over the dominant chords, walking bass.

### Jazz

The one family where the sub-genres genuinely formulate notes differently, so
each gets its own entry.

**Jazz** (the general case) — ii–V–I, sevenths everywhere (`extensions` 0.95),
harmony written by the grammar rather than looked up (`functional` 0.9),
swing 0.32.

**Bebop** — 190–280 bpm, `chromaticism` and `functional` both at 1.0: every
chord is a candidate for tonicisation, and the line is dense (0.85) and
heavily decorated (0.8). Bebop *is* the chromatic approach to the chord tone,
which is precisely what `middaw/embellish.py` writes.

**Big band** — the swing era. Slower than bebop, blockier (`block` figure,
section writing rather than a single line), swing at 0.33 — the triplet.

**Dixieland** — 180–240, collective counterpoint, oom-pah under it, secondary
dominants (I–VI7–II7–V7 is the whole idiom), heavy ornament (0.6). Its form is
the medley or rondo: strains, in order, like the ragtime it came from.

**Modal jazz** — the deliberate opposite of bebop. `functional` 0.1 and
`chromaticism` 0.1: the progression is one chord for four bars, sometimes two.
Dorian, aeolian, mixolydian and lydian are the modes; the interest is the line,
not the changes.

**Smooth jazz** — slow ii–V–I with maj9s, `ballad` and `offbeat` figures, low
velocity. Kept separate from lounge because the harmony is real jazz harmony
played quietly, rather than easy-listening harmony.

**Ragtime** and **bossa** predate this expansion and are unchanged.

### Rock and metal

**Rock** — I–V–vi–IV and I–bVII–IV, block chords, no sevenths to speak of.

**Punk** — 160–200, three chords, `functional` 0.35 because the progression is
a fixed loop rather than an argument, velocity 104, and the lowest `ornament`
and `extensions` of any style (0.05 each). The notes are as plain as they come
and that is the point.

**Metal** — phrygian and harmonic minor first, minor second; bII is the
signature chord. Low register (−2), high velocity (106), ostinato figures
because the riff is the composition. Its twenty splinters in the list (thrash,
death, doom, black, power, sludge, djent, metalcore…) share this harmonic
language; what separates them is tempo, distortion and vocal style, only one of
which Middaw writes.

**Progressive rock** — one of only two styles that weight 7/8 and 5/4 at all
(minimalism is the other), modal (dorian, lydian, mixolydian), harmony played
as an ostinato, and `through_composed` as its first form.

**Surf** — harmonic minor at 140–180, the b2–1 Spanish colour, tremolo picking
modelled as high ornament (0.45).

### Soul, funk and disco

**Soul** — 12/8 as well as 4/4, so the triplet subdivision is written rather
than swung. I–iii–IV–V, gospel-derived; plagal endings are on. Ornament 0.45:
soul melody is decorated melody.

**Funk** — one chord. `functional` 0.15, `progressions` that repeat i7 four
times, density 0.8, and `extensions` at 0.8 because a funk chord is a ninth. The identity is rhythmic, and what Middaw can express of it
is the offbeat figure and the density.

**Disco** — four-on-the-floor at 110–126, ii7–V7–Imaj7 and minor-key
equivalents, arpeggio figures for the strings, sevenths throughout.

**R&B** predates this expansion; **soul** and **motown** were taken out of its
synonyms and given their own style, because a Motown song and a neo-soul song
formulate notes differently.

### Pop and its neighbours

**Pop** — I–V–vi–IV and vi–IV–I–V.

**Synthpop / synthwave** — the same four chords in minor (i–bVI–bIII–bVII),
arpeggiated. Synthwave sits slower (80–112) and darker; synthpop keeps the
major option.

**City pop** — Japanese AOR: maj7 and maj9 harmony, secondary dominants
(`chromaticism` 0.55), `functional` 0.85. Musically this is smooth jazz written
as pop songs, and the entry says so.

**Vaporwave** — city pop and smooth jazz slowed to 58–78 with the extensions
left in. The only style whose defining act (slowing a sample down) Middaw can
reproduce honestly, because tempo is a number.

**Doo-wop** — I–vi–IV–V, the "ice cream changes", in 12/8. The meter is the
idiosyncrasy: the triplet is written, not swung.

**Barbershop** — the circle of fifths as a composition: I–VI7–II7–V7, every
chord a dominant seventh resolving down a fifth. `functional` 1.0,
`chromaticism` 0.7, close harmony, and `extensions` 0.8 so the barbershop
seventh is actually there.

**Lounge**, **new age**, **lullaby** — low density, low velocity, high
`extensions` for lounge and low for lullaby. Lullaby is 6/8 and 3/4 first.

### Dance and electronic

**House / techno** predate this expansion. **Trance** is 132–142, i–bVI–bIII–bVII,
arpeggio-first. **Drum and bass** is 168–176 with sparse, lush harmony —
the notes are few because the drums carry the music, and Middaw writes no
drums, which is worth knowing when the output sounds bare. **Dubstep** is
138–146 in register −3. **UK garage** is the only four-to-the-floor-era style
with real swing (0.2): the shuffled 2-step is its identity, and `grime` routes
here.

**Trip-hop** — 76–96, minor, swung 0.16, low velocity: a slowed boom bap with
lusher chords.

**Boom bap** — taken out of lofi's synonyms and given its own entry: 82–96,
jazz sevenths, swing 0.18. Lofi is the same harmony with the tempo and the
velocity dropped.

### Latin and Caribbean

**Salsa** — 170–210 with the montuno as an ostinato. What is missing is the
clave; see the gaps at the end.

**Samba** — 95–115, ii–V–I with Brazilian sevenths, offbeat figure.

**Bossa** predates this expansion; `samba` was removed from its synonyms.

**Flamenco** — the Andalusian cadence iv–bIII–bII–i, phrygian first, harmonic
minor second, `ornament` 0.7 (the highest outside klezmer and baroque). The
compás — the twelve-beat cycle of the bulería — is not modelled; Middaw writes
it in 3/4 or 4/4 and that is a real simplification.

**Tango** predates this expansion. **Cumbia** is 85–105 with i–V7–i.
**Reggaeton** is the dembow at 88–100 over i–bVI–bVII–V. **Bachata** is
bolero harmony at 118–140, arpeggiated. **Mariachi** is 3/4 and 2/4 ranchera
with V7 everywhere and oom-pah bass.

**Reggae** — the skank: the `offbeat` figure at weight 6, the heaviest any
figure is weighted anywhere (ska matches it), because the chord *only* sounds
on the offbeat. 68–96, minor-key vamps,
low register, plagal endings.

**Ska** — the same upstroke at 140–180 in major.

### Folk, country and dances

**Country** — I–IV–V, mixolydian option for the bVII, walking and oom-pah
figures. **Bluegrass** is the same harmony at 130–180 with the banjo roll
modelled as `arpeggio_up` and density 0.85. **Zydeco** is the Louisiana
two-step: major, oom-pah, occasional I7–IV7–V7.

**Klezmer** — harmonic minor and phrygian (freygish), i–iv–V7–i, and the
highest `ornament` of any style (0.85, ahead of bebop and baroque at 0.8),
because the krekht — the sobbing ornament — is the style. Middaw writes it as diatonic decoration, which is a
fair approximation of where the ornaments go and not of what they sound like.

**Polka** and **march** — the reason `pattern_oompah` was added: bass note on
the beat, chord off it, root and fifth alternating. Polka is 2/4 first; the
march takes 6/8 too and uses V7/V, which is the single most march-like chord
there is.

**Celtic** and **folk** predate this expansion.

### Concert and devotional

**Renaissance** — modal counterpoint: dorian and mixolydian ahead of ionian,
no sevenths (`extensions` 0.05), `functional` 0.3 because functional harmony
had not been invented yet, and plagal endings.

**Impressionist** — lydian, whole tone and pentatonic; `functional` 0.15 and
`extensions` 0.95. Its stock progression Imaj7–ii7–iii7–IVmaj7 is planing: the
same voicing moved in parallel, which is the classical prohibition turned into
a technique.

**Hymn** — four-part chorale, `functional` 1.0, no extensions, plagal endings
available, and `bach chorale` routes here rather than to baroque, because the
chorale is a harmony exercise rather than a keyboard style.

**Baroque**, **classical** and **romantic era** predate this expansion.

## The shared devices

The recurring machinery, each named once:

| Device | Shape | Used by |
| --- | --- | --- |
| Twelve-bar blues | I7 I7 I7 I7 IV7 IV7 I7 I7 V7 IV7 I7 V7 | blues, boogie-woogie, rockabilly, zydeco, jump blues |
| ii–V–I | pre-dominant, dominant, tonic, with sevenths | jazz, bebop, big band, smooth jazz, city pop, lounge, bossa, salsa, samba, disco |
| Doo-wop changes | I vi IV V | doo-wop, soul, fifties pop, ska |
| Four-chord loop | I V vi IV, or vi IV I V | pop, synthpop, punk, reggae |
| Minor four-chord loop | i bVI bIII bVII | trance, synthwave, trap, metal, cinematic |
| Andalusian cadence | iv bIII bII i | flamenco, surf, metal (as bII) |
| Modal vamp | one or two chords, no cadence | modal jazz, funk, afrobeat, house, techno |
| Circle of fifths | I VI7 II7 V7 | barbershop, dixieland, ragtime |
| bVII | the subtonic, borrowed from mixolydian | rock, country, folk, celtic, reggae, prog rock |
| Four on the floor | every beat | house, techno, disco, trance |
| The skank | chord on the offbeat only | reggae, ska, UK garage |
| Oom-pah | bass on the beat, chord off it | polka, march, dixieland, mariachi, zydeco, country |
| Walking bass | crotchet per beat, chromatic approach | jazz, big band, boogie-woogie, rockabilly, bluegrass |
| Alberti / broken chord | low–high–middle–high | classical, baroque, lullaby |
| Montuno | syncopated two-hand piano ostinato | salsa, latin jazz |

## Deliberately not mapped

The 338 names in the list that do not reach a style, and why. This is the
backlog, in the order it is worth working through — the point of listing it is
that the reason is different in each bucket.

**1. Real gaps — these formulate notes and should be added.** Calypso and soca,
merengue, compas and zouk, highlife as distinct from afrobeat, kwaito and
kuduro, Cape jazz, fado, chanson, schlager, Turkish and Balkan pop, gypsy jazz
as its own style rather than a jazz synonym, and bolero as distinct from
bachata. Each needs a tempo band, a mode, a progression and a figure — the work
is the research, not the code.

**2. Non-Western theory — out of scope by design.** Carnatic, Hindustani,
qawwali, filmi, ghazal, bhangra, baila, luk thung, morlam, dangdut, piphat,
gamelan, and the Arabic maqam family (khaliji, sawt, fijiri, fann at-tanbura).
These use tuning systems, modal systems and rhythmic cycles that are not
Western, and Middaw is a Western music-theory system throughout
(`docs/THEORY.md`). Approximating a raga with a church mode would be worse than
declining.

**3. Repertoire or occasion, not style.** Christmas, Chanukah, Easter,
Halloween, Thanksgiving, wedding music, drinking songs, jingles, TV themes,
fitness and workout, travel, nature. "Christmas: Jazz" is jazz. These describe
when music is played, not how its notes are chosen.

**4. Medium or performance, not note formation.** Karaoke, a cappella, spoken
word, comedy, stand-up, novelty, parody, vaudeville, musicals, opera, ballet,
oratorio, cantata, mass, choral, anime, Disney, video-game music as a category,
foreign cinema, turntablism, DJ mixes. Several of these have rich note content
(opera, oratorio) but it is the classical writing already covered, and what
makes them the thing they are is voices and staging.

**5. Timbre or process, not pitch.** Noise, Japanoise, power electronics,
musique concrète, acousmatic music, field recording, tape music, live coding,
sound art, glitch, shoegaze, most of IDM, vaporwave's splinters (mallsoft,
vaportrap, protovapor). Where the identity is the sound rather than the notes,
a MIDI-first generator has nothing honest to write.

**6. Splinters whose notes are the parent's.** Britpunk, crust punk, doomcore,
terrorcore, makina, jumpstyle, nu skool breaks, Florida breaks, ghettotech,
electroclash, indietronica, and a long tail like them. Most now route to a
parent by synonym; the remainder differ in production, scene or speed alone.

**7. Regions and headings, not genres.** Africa, Asia, Europe, Australia,
North and South America, Japan, France, Hawaii, Middle East, Caribbean, and the
family headings themselves.

## What would most improve genre fidelity

In the order it would be heard:

1. **Clave and tresillo.** Salsa, samba, reggaeton, cumbia, afrobeat and
   bachata are *defined* by a rhythmic cell that spans two bars, and Middaw has
   no way to express one. This is the single biggest genre-accuracy gap, and it
   shares a cause with the subdivision-grouping gap in `docs/THEORY.md`.
2. **Drums.** `drums` is a vocabulary tag with nothing behind it. Half the
   styles above — trap, drum and bass, dubstep, funk, ska — put most of their
   identity in a kit Middaw does not write. Channel 10 and the Groove MIDI
   Dataset are the route (`docs/ROADMAP.md`).
3. **Half-time and double-time feel.** Dubstep at 140 is heard at 70; drum and
   bass at 174 is heard at 87. Tempo alone cannot say this.
4. **Instrument-idiomatic voicing.** Everything is written for piano, so a
   power chord, a banjo roll, a horn-section stab and a string pad all come out
   as the same voicing in the same register.
5. **Per-section arrangement.** A disco track and a hymn have the same
   section-to-section dynamic plan. Genre should shape the arc, not just the
   notes inside a section.

## Appendix: every style at a glance

Generated from `data/vocab/tags.json`, which stays the authority if the two
ever disagree. Modes and figures are shown by their heaviest weights.

| Style | BPM | Modes | Meter | Figure | Form | Swing | 7ths | Orn |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Afrobeat | 100–130 | dorian, mixolydian | 4/4 | ostinato | strophic, binary | 0.05 | 0.60 | 0.30 |
| Ambient | 54–78 | lydian, major | 4/4 | sustained | through_composed, strophic | 0.00 | 0.80 | 0.20 |
| Bachata | 118–140 | minor, major | 4/4 | arpeggio_updown | aaba, strophic | 0.05 | 0.40 | 0.40 |
| Ballad | 62–80 | major, minor | 4/4 | ballad | aaba, ternary | 0.00 | 0.35 | 0.35 |
| Barbershop | 80–112 | major | 4/4 | block | aaba, strophic | 0.10 | 0.80 | 0.20 |
| Baroque | 84–132 | major, minor | 4/4 | arpeggio_up | binary, binary_repeated | 0.00 | 0.10 | 0.80 |
| Bebop | 190–280 | major, minor | 4/4 | walking | aaba, binary | 0.30 | 1.00 | 0.80 |
| Big band | 120–200 | major, minor | 4/4 | block | aaba, rondo | 0.33 | 0.80 | 0.40 |
| Bluegrass | 130–180 | major, mixolydian | 4/4 | arpeggio_up | binary_repeated, strophic | 0.05 | 0.15 | 0.45 |
| Blues | 78–120 | blues, minor_pentatonic | 4/4 | block | strophic | 0.30 | 0.70 | 0.45 |
| Boogie-woogie | 150–200 | mixolydian, blues | 4/4 | broken_octave | strophic | 0.30 | 0.50 | 0.45 |
| Boom bap | 82–96 | minor, dorian | 4/4 | offbeat | strophic, aaba | 0.18 | 0.70 | 0.25 |
| Bossa nova | 112–140 | major, dorian | 4/4 | offbeat | aaba | 0.05 | 0.95 | 0.40 |
| Celtic | 110–150 | dorian, mixolydian | 6/8 | arpeggio_up | binary_repeated, binary | 0.00 | 0.05 | 0.45 |
| Chiptune | 120–172 | major, minor | 4/4 | arpeggio_up | binary_repeated, ternary | 0.00 | 0.10 | 0.25 |
| Cinematic | 66–104 | minor, dorian | 4/4 | ostinato | ternary, through_composed | 0.00 | 0.30 | 0.30 |
| City pop | 98–122 | major, dorian | 4/4 | offbeat | aaba | 0.05 | 0.95 | 0.35 |
| Classical | 76–132 | major, minor | 4/4 | alberti | ternary, rondo | 0.00 | 0.15 | 0.65 |
| Country | 90–130 | major, mixolydian | 4/4 | block | strophic, aaba | 0.10 | 0.20 | 0.25 |
| Cumbia | 85–105 | minor, major | 4/4 | offbeat | strophic, binary | 0.00 | 0.25 | 0.25 |
| Disco | 110–126 | minor, major | 4/4 | offbeat | strophic, binary | 0.04 | 0.70 | 0.30 |
| Dixieland | 180–240 | major, mixolydian | 4/4 | oompah | medley, rondo | 0.30 | 0.55 | 0.60 |
| Doo-wop | 108–140 | major | 12/8 | rolled | aaba, strophic | 0.30 | 0.30 | 0.30 |
| Drum and bass | 168–176 | minor, dorian | 4/4 | sustained | binary, strophic | 0.00 | 0.75 | 0.20 |
| Dubstep | 138–146 | minor, phrygian | 4/4 | sustained | binary, strophic | 0.00 | 0.20 | 0.10 |
| Flamenco | 100–150 | phrygian, harmonic_minor | 4/4 | rolled | through_composed, binary | 0.00 | 0.30 | 0.70 |
| Folk | 88–124 | major, mixolydian | 4/4 | block | strophic, binary | 0.05 | 0.10 | 0.35 |
| Funk | 95–120 | dorian, mixolydian | 4/4 | offbeat | strophic, binary | 0.10 | 0.80 | 0.35 |
| Gospel | 72–108 | major, mixolydian | 4/4 | block | strophic, aaba | 0.22 | 0.80 | 0.55 |
| House | 118–128 | minor, dorian | 4/4 | offbeat | strophic, binary | 0.06 | 0.70 | 0.15 |
| Hymn | 60–92 | major, minor | 4/4 | block | strophic, period | 0.00 | 0.15 | 0.20 |
| Impressionist | 56–96 | lydian, major | 4/4 | arpeggio_updown | ternary, through_composed | 0.00 | 0.95 | 0.50 |
| Jazz | 100–160 | major, dorian | 4/4 | offbeat | aaba, rondo | 0.32 | 0.95 | 0.55 |
| Klezmer | 100–160 | harmonic_minor, phrygian | 4/4 | offbeat | binary_repeated, rondo | 0.05 | 0.35 | 0.85 |
| Lo-fi | 70–88 | dorian, minor | 4/4 | offbeat | strophic, aaba | 0.17 | 0.85 | 0.30 |
| Lounge | 88–120 | major, minor | 4/4 | ballad | aaba, ternary | 0.20 | 0.90 | 0.45 |
| Lullaby | 58–80 | major, major_pentatonic | 6/8 | rolled | strophic, period | 0.00 | 0.10 | 0.15 |
| March | 100–128 | major, minor | 4/4 | oompah | rondo, medley | 0.00 | 0.20 | 0.25 |
| Mariachi | 100–150 | major, minor | 3/4 | oompah | strophic, binary_repeated | 0.00 | 0.25 | 0.40 |
| Metal | 110–180 | phrygian, minor | 4/4 | ostinato | binary, ternary | 0.00 | 0.10 | 0.15 |
| Minimalism | 96–144 | major, minor | 4/4 | ostinato | strophic, through_composed | 0.00 | 0.20 | 0.10 |
| Modal jazz | 100–150 | dorian, mixolydian | 4/4 | block | binary, through_composed | 0.25 | 0.90 | 0.50 |
| New age | 52–80 | major, lydian | 4/4 | arpeggio_updown | through_composed, strophic | 0.00 | 0.50 | 0.20 |
| Polka | 110–145 | major | 2/4 | oompah | binary_repeated, rondo | 0.00 | 0.15 | 0.30 |
| Pop | 96–128 | major, minor | 4/4 | block | aaba, strophic | 0.00 | 0.20 | 0.25 |
| Progressive rock | 100–150 | dorian, mixolydian | 4/4 | ostinato | through_composed, rondo | 0.00 | 0.45 | 0.35 |
| Punk | 160–200 | major, mixolydian | 4/4 | block | strophic, binary | 0.00 | 0.05 | 0.05 |
| R&B | 72–96 | minor, dorian | 4/4 | offbeat | aaba | 0.20 | 0.95 | 0.40 |
| Ragtime | 88–116 | major | 4/4 | broken_octave | rondo, medley | 0.00 | 0.35 | 0.50 |
| Reggae | 68–96 | minor, major | 4/4 | offbeat | strophic, aaba | 0.08 | 0.35 | 0.15 |
| Reggaeton | 88–100 | minor, aeolian | 4/4 | ostinato | strophic, binary | 0.00 | 0.30 | 0.20 |
| Renaissance | 72–104 | dorian, ionian | 4/4 | sustained | binary, through_composed | 0.00 | 0.05 | 0.45 |
| Rock | 104–156 | minor, mixolydian | 4/4 | block | aaba, strophic | 0.00 | 0.10 | 0.20 |
| Rockabilly | 150–190 | mixolydian, major | 4/4 | walking | strophic, aaba | 0.28 | 0.40 | 0.30 |
| Romantic era | 60–96 | minor, major | 4/4 | arpeggio_updown | ternary, rondo | 0.00 | 0.35 | 0.70 |
| Salsa | 170–210 | major, minor | 4/4 | ostinato | binary, strophic | 0.00 | 0.60 | 0.35 |
| Samba | 95–115 | major, minor | 4/4 | offbeat | aaba, binary | 0.06 | 0.80 | 0.35 |
| Ska | 140–180 | major, minor | 4/4 | offbeat | aaba, strophic | 0.18 | 0.30 | 0.20 |
| Smooth jazz | 88–116 | major, dorian | 4/4 | ballad | aaba, ternary | 0.12 | 0.95 | 0.40 |
| Soul | 72–104 | major, mixolydian | 4/4 | block | aaba, strophic | 0.15 | 0.60 | 0.45 |
| Surf | 140–180 | harmonic_minor, minor | 4/4 | ostinato | binary_repeated, aaba | 0.05 | 0.15 | 0.45 |
| Synthpop | 108–132 | major, minor | 4/4 | ostinato | aaba, strophic | 0.00 | 0.25 | 0.15 |
| Synthwave | 80–112 | minor, aeolian | 4/4 | arpeggio_up | binary, strophic | 0.00 | 0.40 | 0.20 |
| Tango | 100–132 | harmonic_minor, minor | 4/4 | ostinato | binary, ternary | 0.00 | 0.30 | 0.45 |
| Techno | 128–142 | minor, phrygian | 4/4 | ostinato | strophic | 0.00 | 0.15 | 0.08 |
| Trance | 132–142 | minor, aeolian | 4/4 | arpeggio_up | binary, strophic | 0.00 | 0.30 | 0.20 |
| Trap | 130–150 | minor, phrygian | 4/4 | ostinato | aaba, strophic | 0.10 | 0.30 | 0.15 |
| Trip-hop | 76–96 | minor, dorian | 4/4 | ballad | strophic, aaba | 0.16 | 0.60 | 0.25 |
| UK garage | 128–138 | minor, dorian | 4/4 | offbeat | strophic, binary | 0.20 | 0.70 | 0.30 |
| Vaporwave | 58–78 | major, dorian | 4/4 | sustained | strophic, through_composed | 0.08 | 0.95 | 0.25 |
| Waltz | 96–168 | major, minor | 3/4 | waltz | ternary, rondo | 0.00 | 0.20 | 0.50 |
| Zydeco | 120–165 | major, mixolydian | 4/4 | oompah | binary_repeated, strophic | 0.15 | 0.25 | 0.35 |
