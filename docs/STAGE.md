# The stage

From 11 November 2026 Middaw's window is not a list of tracks. It is an
orchestra seen from above, the audience at the bottom: a seat for every
player, and a row at the front for everything that is not an orchestra.
Click an empty seat and choose what plays it - an Audio Unit instrument on
the Mac, or one of Middaw's own sounds. Click a player and their part opens
underneath, as MIDI, notation, drums or a step sequencer. Where a player sits
decides how the hall sounds on them; at the front nothing is added.

```
                         S     A     T     B                    (choir)
             Cel   Perc   Glk   Timp   Xyl   Mar   Vib          (percussion)
        Hp  Pno  Hn4 Hn3 Hn2 Hn1  Tpt3 Tpt2 Tpt1  Tbn1 Tbn2 B.tbn Tba   Cb
     Vln I      B.cl  Cl 2  Cl 1   Bsn 1  Bsn 2  Cbsn
                Picc  Fl 2  Fl 1   Ob 1   Ob 2   C.a.             Vc
                  Violins II   |   Violas
                           ( Concert Hall )                 the podium: the hall
 Front  [Synth Lead] [Drum Machine]                 + Instrument  + Drum Machine
 Part   ▭▭▭▭▭▭▭▭   (the chosen player's clips over the song)
 [MIDI | Notation | Drums | Step Sequencer]  Devices          | Generate (beside)
```

The orchestra is drawn as a fan of rings around the conductor, as seating
charts draw it: each seat a wedge between two angles and two radii.

## Where it came from

What other software does, and what was taken:

| | What it does | Taken here |
| --- | --- | --- |
| **Vienna MIR Pro** | Instruments are icons placed on a recorded stage; each position plays through impulse responses recorded there (hundreds per microphone position, interpolated), heard from a main microphone position | The idea: the stage is the mixer, and position decides the room. The seating is a fixed chart rather than free placement |
| **Parallax VirtualSoundStage** | Places an instrument on a virtual scoring stage heard through a Decca tree: position-specific early reflections, width, directivity, air absorption, the direct signal kept clean | The listener over the conductor; width per seat; air absorption; reflections computed per seat; the direct sound untouched by the room |
| **Spitfire, Orchestral Tools, BBC SO** | Libraries recorded in their seats ("pre-seated") with close, tree and ambient microphones | Why each seat keeps only part of a plug-in's own stereo: a library's close microphones belong on the stage, its tree already has a room |
| **Logic Pro, Cubase** | Drum editors: a lane per drum, hits as diamonds, velocity as a shade | The Drums tab |
| **FL Studio's channel rack, Logic's Step Sequencer** | A row per drum or per pitch, a cell per step; click to toggle, drag to paint; accents | The step sequencer, with Middaw's accent, normal and ghost (the `X x o` its drum patterns are written in) |
| **Every Mac DAW** | Audio Units, through Core Audio | Plug-in hosting, with nothing added to the app |

[MIR Pro's instrument settings](https://www.vsl.co.at/manuals/mir-pro-3d/instrument-settings),
[VSL's RoomPack pages](https://www.vsl.co.at/manuals/mir-roompacks/roompack1),
[VirtualSoundStage 2 on KVR](https://www.kvraudio.com/product/virtualsoundstage-2-by-parallax-audio),
[Logic's Step Sequencer](https://support.apple.com/HT211026). Nothing was
copied from any of them; no impulse response here was recorded anywhere.

## The seating

American seating, as most orchestras sit today, in a fan around the
conductor (`Stage.seats` in `mac/Sources/MiddawCore/Stage.swift`):

| ring (metres from the conductor) | from the left |
| --- | --- |
| 2.5–5 | Violins II, Violas - with Violins I (2.5–8) outside them on the left and Cellos (2.5–6.5) on the right |
| 5–6.5 | Piccolo, Flute 2, Flute 1, Oboe 1, Oboe 2, Cor Anglais |
| 6.5–8 | Bass Clarinet, Clarinet 2, Clarinet 1, Bassoon 1, Bassoon 2, Contrabassoon - Basses (6.5–9.5) beyond the cellos |
| 8–9.5 | Harp, Piano, Horns 4–1, Trumpets 3–1, Trombones 1–2, Bass Trombone, Tuba |
| 9.5–11 | Celesta, Percussion, Glockenspiel, Timpani, Xylophone, Marimba, Vibraphone |
| 11–12.5 | Sopranos, Altos, Tenors, Basses (the choir, on risers) |

Strings and choir are a seat per section (a section library is one
plug-in); winds and brass a seat per player, the principals in the middle.

**Where a seat is drawn is where it is heard from**: its position is the
middle of its wedge, `x` across the stage (negative to the left) and `depth`
back from the front edge where the conductor stands; `height` is where the
instrument sounds from. The listener is the main microphone pair, 3 m in
front of the conductor and 3.5 m up, where a Decca tree hangs.

An orchestral instrument asked for by name (Stage > Add a Player, an ensemble,
Compose, a song from before the stage) takes the first free seat for it. The
piano is the exception: it is as often a band's as an orchestra's, so it
takes the piano seat only when asked for on its own or by an orchestral
ensemble. A kit asked for by a band plays at the front; the percussion seat
holds a kit only when it is put there.

## What the hall does to each seat

Each seat's impulse response is three things, and the renderer convolves
the song with it:

1. **The direct sound.** Panned to where the seat is (constant power, the
   sine of the angle widened by a quarter, as a spaced pair widens a stage),
   as loud as the inverse-square law says beside a reference distance of 7 m,
   and darkened by air: a one-pole low-pass at 16 kHz × e^(−r/25 m). The
   plug-in's own stereo is narrowed to the seat's width (a section 0.35–0.5,
   a solo wind 0.1). Every seat's direct sound arrives at the same moment:
   the distance is heard in level, colour and reverberation, not as a delay,
   because a player 10 m back plays ahead of the beat to be with it.
2. **The early reflections**, by Allen and Berkley's image method in a box
   the size of the hall, up to the second order, within 150 ms of the direct
   sound. Each wall takes a share set by Sabine's equation: the hall's
   average absorption is what its size and reverberation time say it must
   be. The stage floor is left out: players and chairs stand between it and
   the microphones. Some fifteen sparse taps a seat, convolved directly.
3. **The late reverberation**, decorrelated noise in each ear falling 60 dB
   over RT60, darkening as it falls, building up from 12 ms. A diffuse tail
   is the same from every seat - only its level beside the direct sound
   changes, and that falls out of the direct sound's distance - so one tail
   serves the whole stage and is convolved once, by uniformly partitioned
   FFT (`Convolver`, exact and with no delay: the head is convolved
   directly, which is exactly the block the partitioned part is late by). Its
   energy is set so that a source at the critical distance, 0.057 √(Q V /
   RT60) with Q = 2, hears as much tail as direct sound.

What comes out, in the Concert Hall (26 × 44 × 18 m, RT60 2.0 s, critical
distance 8.2 m):

| seat | position | distance | pan | direct | direct against the tail |
| --- | --- | --- | --- | --- | --- |
| Cellos | +4.3, 1.2 m | 6.6 m | right 90 | +0.0 dB | +1.4 dB |
| Violins I | −5.1, 1.4 m | 7.1 m | left 95 | −0.1 dB | +1.2 dB |
| Oboe 1 | +1.0, 5.7 m | 9.0 m | right 14 | −2.2 dB | −0.8 dB |
| Basses | +7.7, 2.1 m | 9.6 m | right 100 | −2.7 dB | −1.4 dB |
| Harp | −8.7, 1.1 m | 9.9 m | left 100 | −3.0 dB | −1.7 dB |
| Horn 1 | −3.7, 7.9 m | 11.7 m | left 40 | −4.4 dB | −3.1 dB |
| Timpani | 0.0, 10.2 m | 13.4 m | centre | −5.6 dB | −4.3 dB |
| Sopranos | −8.3, 8.3 m | 14.1 m | left 74 | −6.1 dB | −4.7 dB |

The halls:

| | size | RT60 | critical distance |
| --- | --- | --- | --- |
| Concert Hall | 26 × 44 × 18 m | 2.0 s | 8.2 m |
| Scoring Stage | 30 × 40 × 12 m | 1.4 s | 8.2 m |
| Studio | 24 × 25 × 8 m | 0.6 s | 7.2 m |

## The front

Synths, samplers, drum machines, a band: as many as you like, each heard as
it is, dry and in the middle - its own stereo untouched. Add one with
**Instrument** or **Drum Machine** at the end of the row; a drum machine's
notes are drums (channel 10, never transposed, never fitted to a key).

## Plug-ins

Audio Units, through Core Audio: `PluginCatalog` lists every instrument
installed, `PluginHost` makes them (asynchronously; the seat is silent until
it opens) and the renderer plays them inside its own block, their MIDI
scheduled at sample offsets. A plug-in's state is saved in the song (its
`fullStateForDocument`, as a property list). **Show the Plug-in Window**
opens the maker's own window.

VST3 is not hosted. On the Mac every instrument sold as VST3 also ships as
an Audio Unit - Logic Pro hosts nothing else - and hosting VST3 would mean
adding Steinberg's SDK, against the rule that the app adds no third-party
code.

## What it cannot do yet

- **The seating is fixed.** A wedge cannot be dragged; a player can move to
  any free seat or to the front, from Player > Seat or the seat's menu.
- **No directivity.** Every instrument radiates the same way in every
  direction; a horn's bell pointing backwards is not modelled.
- **No measured halls.** The rooms are calculated, not recorded. A measured
  impulse response could replace the tail without changing anything else.
- **Not heard.** CI renders every seat and checks the sound as numbers: the
  firsts are left, the cellos right, the timpani further away, the studio
  drier than the hall, the convolver exact to the sample. Nobody has yet
  listened to it on speakers.
