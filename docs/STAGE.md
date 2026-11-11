# The stage

From 11 November 2026 Middaw's window is not a list of tracks. It is an
orchestra seen from above, the audience at the bottom: a seat for every
player, and a row at the front for everything that is not an orchestra.
Click an empty seat and choose what plays it - an Audio Unit instrument on
the Mac, or one of Middaw's own sounds. Click a player and their part opens
underneath, as MIDI, notation, drums or a step sequencer. Where a player sits
decides how the hall sounds on them; at the front nothing is added.

```
┌ Stage ─────────────────────────────── Concert Hall ▾ ┐
│        S        A        T        B          (choir) │
│  Perc Glk Xyl      Timp      Mar Vib     (percussion) │
│ Hn4 Hn3 Hn2 Hn1 Tpt3 Tpt2 Tpt1 Tbn1 Tbn2 B.tbn Tba    │
│ Cel     B.cl Cl2 Cl1   Bsn1 Bsn2 Cbsn                 │
│        Picc Fl2 Fl1   Ob1 Ob2 C.a.                    │
│ Hp                                          Cb        │
│      Vln II                    Vla                    │
│ Pno  Vln I                          Vc                │
│ ─────────────────── (podium) ──────────────────────── │
│ Front  [Synth Lead] [Drum Machine]  + Instrument  + Drum Machine │
└────────────────────────────────────────────────────────┘
  Part   ▭▭▭▭▭▭▭▭   (the chosen player's clips over the song)
  [MIDI | Notation | Drums | Step Sequencer]   Devices
```

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

American seating, as most orchestras sit today (`Stage.seats` in
`mac/Sources/MiddawCore/Stage.swift`): first violins on the conductor's left,
cellos on the right, seconds and violas inside them, basses behind the
cellos; harp, piano and celesta on the left; flutes and oboes in front of
clarinets and bassoons, the principals in the middle; horns to the left of
the brass, trumpets in the middle, trombones and tuba to the right;
percussion and timpani at the back; the choir on risers behind. Strings and
choir are a seat per section (a section library is one plug-in); winds and
brass a seat per player.

Coordinates are metres seen from the audience, `x` across, `depth` back
from the stage's front edge, `height` where the instrument sounds from. The
stage is 13 m deep. The listener is the main microphone pair, 3 m in front
of the stage and 3.5 m up, where a Decca tree hangs over the conductor.

An orchestral instrument asked for by name (the browser, an ensemble,
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

| seat | distance | pan | direct | direct against the tail |
| --- | --- | --- | --- | --- |
| Violins I | 7.3 m | left 90 | −0.4 dB | +0.9 dB |
| Cellos | 7.5 m | right 88 | −0.6 dB | +0.7 dB |
| Oboe 1 | 9.9 m | right 10 | −3.0 dB | −1.6 dB |
| Harp | 11.0 m | left 84 | −3.9 dB | −2.6 dB |
| Basses | 11.3 m | right 81 | −4.2 dB | −2.8 dB |
| Horn 1 | 13.1 m | left 36 | −5.4 dB | −4.1 dB |
| Timpani | 14.1 m | centre | −6.1 dB | −4.7 dB |
| Sopranos | 16.1 m | left 35 | −7.2 dB | −5.9 dB |

The halls:

| | size | RT60 | critical distance |
| --- | --- | --- | --- |
| Concert Hall | 26 × 44 × 18 m | 2.0 s | 8.2 m |
| Scoring Stage | 30 × 40 × 12 m | 1.4 s | 8.2 m |
| Studio | 20 × 25 × 8 m | 0.6 s | 6.6 m |

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

- **The seating is fixed.** A seat cannot be dragged; a player can move to
  any free seat or to the front, from the inspector or the seat's menu.
- **No directivity.** Every instrument radiates the same way in every
  direction; a horn's bell pointing backwards is not modelled.
- **No measured halls.** The rooms are calculated, not recorded. A measured
  impulse response could replace the tail without changing anything else.
- **Not heard.** CI renders every seat and checks the sound as numbers: the
  firsts are left, the cellos right, the timpani further away, the studio
  drier than the hall, the convolver exact to the sample. Nobody has yet
  listened to it on speakers.
