# The DAW

Middaw is a DAW that is generative from the first screen: describe the music
and it is written as five parts on five tracks, or start from an ensemble and
write it yourself. Either way it stays MIDI - notes you can see, edit, hear,
engrave and export - and every generator and device works on what is already
there.

```sh
python3 server/app.py        # then open http://127.0.0.1:8765
```

## Where the family lives

Nothing here is a re-implementation. The Lua engines run **unchanged** in
Middaw's own Lua 5.4 (`web/lua/`, held byte for byte to the real Lua by the
tests), and the JSFX devices run **unchanged** in Middaw's own EEL2 compiler
(`web/jsfx/`). A fix to a family project is made there and synced here
(`web/engines/VENDORED.md`, `web/devices/VENDORED.md`).

| Project | Where it is | What it does here |
| --- | --- | --- |
| **Middaw** (this repo's Python) | Welcome prompt; Generate → **Compose** | A sentence becomes melody, countermelody, harmony, bass and drums on five tracks, with the key, tempo and meter set. *Add to the Song* puts another take at the caret |
| **ScaleView** | The key display in the toolbar; the chords lane; every chord name | The key's notes lit on one octave, what is sounding ringed, the chord named beside it. `middaw/scaleview.py` on the server; Midi Variator's copy of the reader in the browser |
| **Good Idea** | Generate → **Generate** | An idea is a number: a motif, phrase or measure in the song's key, auditioned on piano, inserted at the caret |
| **Midi Suggester** | Generate → **Suggest**; *Suggest…* on a clip | Reads the chosen clip and writes the part that goes with it - chords under a tune, a tune over chords, a bass - **on a new track beside it** (Miderator 0040) |
| **Midi Variator** | Generate → **Vary**; *Vary…* on a clip | Variations of the chosen clip, each saying what it changed; the chosen one replaces the clip, as one undo step |
| **Starting Blocks** | The **Blocks** bar over the piano roll | A button per degree of the key: click to hear the chord, run or arpeggio, double-click to put it at the caret. The caret moves on, so blocks laid in a row become a phrase. Step input uses the same path |
| **Starting Blocks Notation** | The **Score** tab | Each part engraved the way Starting Blocks Notation prints a block; *Full Score* for every track, a light page for reading |
| **Midi Catalogue** | Browser → **Ideas** | Browse the catalogue for the chosen instrument and key, audition, insert. Its *Shape It* transforms are the clip's **Transform** menu, done inside the key |
| **Noterator** | Browser → **Sounds** → Ensembles; File → New | The ensembles (String Quartet, Big Band, Beat Maker…) build their tracks with the right instruments; its adapters are how every engine is driven |
| **Miderator** | Throughout | Its decisions are the placement rules: the chosen bars across tracks are where generated music goes (0019); a result is fitted to the instrument's range and polyphony (0036); tune at the top, bass at the bottom (0041–0042); results audition on piano and kit (0043) |
| **Orchestration Helper** | The inspector's **About**; Browser → **Guide** | What the instrument on the chosen track is good at, from Rimsky-Korsakov, Berlioz and Lavignac; searchable by instrument, composer or character |
| **Instrument Creator** | Sound → *Instrument Creator* | Physical modelling as an instrument: nineteen of its instruments by name, or build your own |
| **Instant Virtual Instrument** | Sound → *Instant Instrument* | Drop a sound on a track and play it across the keyboard. (The repository holds only a licence, so this is built from its name) |
| **Transient Shuffler** | Sound → *Transient Shuffler* | Drop two sounds; it plays one with the other's attack |
| **AutoCC** | MIDI Effects → *AutoCC*; *Draw Dynamics with AutoCC* on a clip | Live: dynamics and expression curves from how you play. On a clip: the same curves **drawn into the clip's CC lanes**, to edit like any other automation |
| **Midi Evolver** | MIDI Effects → *Midi Evolver* | Hold a chord and it evolves it; *Insert the Take* puts what it played into the track as notes |
| **MIDI Production Center** | MIDI Effects → *MIDI Production Center* | *Load the Chosen Clip* chops a clip onto its pads, through its own loader protocol |
| **Reverberator** | The **Reverb** return, every track's *Reverb* send; Audio Effects | One shared space for the song, plus an insert where a track wants its own |
| **DAW Battle Pass** | The ring in the toolbar | Its game, unchanged: active minutes fill the tier, quests come from what you actually do in Middaw, loot includes ideas that appear in the browser. Saved to `data/user/` through the server |

## What it shares with other DAWs

Chosen because musicians already know them, not invented:

- **Arrange over editor**, as in Logic, Cubase and Bitwig: tracks and clips on
  top, the chosen clip's notes underneath, a divider between them.
- **Inspector on the right** (Cubase, Logic, Pro Tools' Edit window): the
  chosen track's instrument, sound, MIDI effects, audio effects, mix.
- **Browser on the left** (Ableton, Bitwig, FL Studio).
- **Devices in a chain**: MIDI effects → instrument → audio effects, as
  Ableton and Bitwig order them; a reverb on a return, as every console does.
- **Piano roll** with draw tool, lasso, velocity and CC lanes, quantize,
  triplets, the instrument's range bracketed beside the keys and the key's
  notes shaded (Cubase's and Logic's scale assistants; Studio One's scale).
- **Chord track** (Cubase, Studio One): the chords lane names what the
  accompaniment plays, beat by beat.
- **Score view** (Cubase, Logic, Digital Performer's QuickScribe).
- **Step input** with the transport stopped, recording with it running.
- **Loop**, metronome, follow, Home/End, Space, the keys every DAW uses.
- **Mixer** with a strip per track, pan, send, fader in dB and meters.
- **Export** to a Standard MIDI File (Middaw's own writer, with CC) and to
  WAV, rendered through the same devices faster than real time.

## Using it

Every action is a button, a menu item and (where it is frequent) a key. The
toolbar's help is in **View → Keyboard Shortcuts** (H). The things that are
not obvious from the screen:

- **Generated music goes where you chose.** Drag across bars in the arrange
  view (across tracks too) and Generate fills them; with nothing chosen it
  goes at the caret on the chosen track; a suggestion goes on a new track.
- **Everything is one undo step**, named in Edit → Undo, and the status line
  offers Undo after anything large.
- **A result is heard before it is used**: on piano, or on the kit for drums,
  so the choice is about the notes.
- **Devices keep their state in the song**: Midi Evolver's take, MIDI
  Production Center's phrase, sounds dropped on a sampler. Save writes it all
  into the `.middaw` file.

## How it is built

```
web/index.html      the window
web/style.css       the house scheme (docs/COLOUR.md)
web/app/model.js    the song: tracks, clips, notes, undo
web/app/engines.js  the Lua engines, driven through Noterator's adapters
web/app/devices.js  the JSFX devices and how their controls are grouped
web/app/audio.js    one audio-thread processor per track (worklet.js), the
                    reverb return, transport, audition, WAV render
web/app/synths.js   Middaw's own synth presets, kit and sampler
web/app/ui/         one file per part of the window; main.js wires them
web/lua/            Lua 5.4: parser, compiler to JS, runtime and stdlib
web/jsfx/jsfx.js    EEL2 compiler and the JSFX runtime
web/engines/        the family's Lua, unchanged
web/devices/        the family's JSFX, unchanged
server/app.py       Compose, MIDI in and out, storage
```

Each track's processor runs its chain sample-accurately from the audio clock,
so playback stays in time however busy the page is. Nothing about a device's
sound is approximated: the JSFX is compiled from its own source, and its
sliders are its own (grouped so the ones you reach for come first; the rest
are under *More*).

## Known limits

- **@gfx is not run.** A device's own drawing is replaced by controls built
  from its slider lines; the MPC's pads are Middaw's buttons.
- **Integers beyond 2^53 in Lua are approximate.** No engine uses them; the
  conformance tests mark the cases.
- **Middaw Synth is not a sampled orchestra.** The presets are recognisable,
  not realistic; Instrument Creator and Instant Instrument are the richer
  sounds today.
- **The score writes each note up to the next one**, as Starting Blocks
  Notation does for a block, so a rest inside a phrase prints as a longer
  note. Onsets are put back on the sixteenth or triplet grid before engraving.
- **Not yet tried on real speakers or a real MIDI keyboard.** Everything was
  exercised in headless Chromium (transport, every generator, every device,
  both exports); the sound itself and Web MIDI need a person.
- **Reverberator's own `check.py`** needs SciPy, which this sandbox lacks, and
  ysfx could not be fetched; Midi Evolver's engine checks (77 of 77) run here
  against Middaw's EEL2 instead.
