# The DAW

Middaw is a native Mac app for Apple silicon: a DAW that is generative from
the first screen. Describe the music and it is written as five parts, or
start from an ensemble and write it yourself. Either way it stays MIDI -
notes you can see, edit, hear, engrave and export - and every generator works
on what is already there.

## The window

Not a list of tracks: **an orchestra seen from above**, a fan of rings
around the conductor (`docs/STAGE.md`). Every player has a wedge of it; click an empty one and choose what plays it - an
Audio Unit instrument on the Mac, or one of Middaw's own sounds. Where the
seat is decides the hall's sound on it: the first violins close and on the
left, the timpani far back in the middle, each with its own reflections and
the hall's tail. Synths, drum machines and anything else that is not an
orchestra go at **the front**, as many as you like, dry and in the middle.

Under the stage, the chosen player's **part** (their clips across the song,
the bars, the loop and the chords) and its editor, in four tabs: **MIDI**
(the piano roll), **Notation** (Starting Blocks Notation's engraving),
**Drums** (a lane per drum) and the **Step Sequencer** - with the player's
**Devices** a button beside them. **Generate** (G, or the toolbar) opens
the generators to the right of the editor, beside the notes they write, as
Ableton shows its own.

There are no side panels: the stage and the editor take the whole width,
and the rest is in the menus at the top. **Stage**: add a player or an
ensemble, a player or a drum machine at the front, the hall. **Player**:
where the chosen player sits and how loud they are heard, their range, and
their name, instrument, seat, sound (Middaw's, the family's, or any Audio
Unit by maker), mute and solo. **Clip**: Vary, Suggest, Transform, Draw
Dynamics with AutoCC, Quantize, Duplicate, Split, Export. The player's level
is the last card in Devices; Midi Catalogue's ideas are Generate's
Catalogue tab; Orchestration Helper's guide is a window of its own (Help). Shift-click more players to show their parts
together and choose bars across them.

(It was a browser app until 30 October 2026; `docs/BROWSER-DAW.md` says what
that was and how to get it back.)

## Getting it

Every push builds it on an Apple silicon Mac in GitHub Actions: open the
**Mac** workflow's latest run on GitHub and download **Middaw-app**. Unzip it,
then the first time right-click **Middaw** and choose **Open** (it is signed
ad hoc, not by a registered developer).

To build it yourself (Xcode 16 or its Command Line Tools):

```sh
mac/scripts/bundle.sh        # -> mac/build/Middaw.app
cd mac && swift run          # or run it straight from source
```

Nothing else to install: Compose runs inside the app too.

## How it is built

```
mac/Package.swift            a Swift package: no Xcode project, no dependencies
mac/Sources/MiddawCore/      the song, undo, editing, keys, MIDI files
mac/Sources/MiddawEngines/   the family's Lua, in JavaScriptCore
mac/Sources/MiddawAudio/     Core Audio: instruments, sequencer, device chains, reverb, bounce; Core MIDI
mac/Sources/CJSFX/           the family's JSFX compiled to C (tools/jsfx2c.js) and its runtime
mac/Sources/Middaw/          the app: SwiftUI windows, documents, menus
mac/Tests/                   XCTest, run by CI on Apple silicon
runtime/                     Lua 5.4 and EEL2, the runtimes the family's code runs in
family/                      the family's engines and devices, unchanged
runtime/composer/            the composer, ported from middaw/ (Python) for Compose
```

- **Documents.** Each song is a macOS document: its own window, Open Recent,
  autosave and versions, and Edit > Undo named for what it undoes. `.middaw`
  files from the browser version open unchanged; a `.mid` opens as a song.
- **The family's code runs unchanged.** Good Idea, Midi Suggester, Midi
  Variator, Starting Blocks (and its notation), Midi Catalogue, DAW Battle
  Pass and Orchestration Helper are Lua; they run in Middaw's Lua 5.4
  (`runtime/lua/`, held byte for byte to the real Lua by the tests) inside
  JavaScriptCore, which every Mac has. AutoCC's Draw Dynamics runs from its
  own JSFX through `runtime/jsfx/`.
- **Compose needs no Python.** `runtime/composer/` is the composer
  (`middaw/`) ported line for line to JavaScript, Python's random-number
  generator and rounding included, and it runs in the same JavaScriptCore as
  the engines. `tests/test_composer_js.py` holds it to the Python on every
  word of the vocabulary and on mixed prompts, seed for seed, and an XCTest
  holds the copy in JavaScriptCore to Python's answers. The corpus priors are
  not ported: `data/corpus` has no entries, and that test fails the day it
  does.
- **The family's JSFX are native devices.** `tools/jsfx2c.js` translates each
  one to C with the JS runtime's own parser and rules, and the C runs on the
  audio thread in the player's chain: MIDI effects, then the instrument, then
  audio effects, as Bitwig and Ableton order them - then the stage. The Devices tab shows the
  chain left to right; each device's controls are its own sliders. The C is
  held to the JS runtime by `tests/test_jsfx_c.py`: the same variables, MIDI
  and samples for every device over random sessions, and Midi Evolver's own
  77 engine checks.
- **The sound is native.** One Core Audio source node renders every player
  sample-accurately from the audio clock; nothing on that thread allocates or
  waits. Audio Unit instruments play inside that same block, their MIDI at
  sample offsets; the hall is a convolution per seat (`docs/STAGE.md`). Middaw Synth's eighteen presets, the drum kit and the Instant
  Instrument are ported from the browser version operation for operation.
- **What CI checks** on a real Apple silicon Mac: the MIDI writer byte for
  byte against `middaw/midi.py`, every key's spelling and signature against
  the ScaleView port, the model, every generator through JavaScriptCore,
  every preset and the kit making sound, notes starting on their beat to the
  sample, mute and solo, the loop, each seat heard from where it is, the
  front dry, the convolver exact, Apple's DLS synth played as an Audio Unit
  in a seat, and the bundle itself.

## Where the family lives

| Project | Where it is |
| --- | --- |
| **Middaw** (the composer) | Generate > Compose: a sentence becomes the song's five parts, key, tempo and meter |
| **ScaleView** | The key display in the toolbar, the chords lane, every chord name |
| **Good Idea** | Generate > Idea: an idea is a number; the same number always gives the same idea |
| **Midi Suggester** | Generate > Suggest, or Suggest… on a clip: the part that goes with it, played by a new player beside it - in a seat if the chosen player has one (Miderator 0040) |
| **Midi Variator** | Generate > Vary, or Vary… on a clip: variations, each saying what it changed |
| **Starting Blocks** | The Blocks bar over the piano roll: click to hear, double-click to put it at the caret, which moves on |
| **Starting Blocks Notation** | The Notation tab, a part or the full score, dark or a light page; a clip's silences are rests (its `opts.rests`) |
| **Midi Catalogue** | Generate > Catalogue; its instruments are every player's Instrument and the stage's seats; its Shape It is Transform |
| **Noterator** | The ensembles (String Quartet, Big Band, Beat Maker…) and the adapters every engine is driven through |
| **Miderator** | The placement rules: into the chosen bars, else at the caret; fitted to the instrument; heard on piano or kit first |
| **Orchestration Helper** | Help > About the instrument, and the Orchestration Guide window |
| **Instant Virtual Instrument** | Played by > Instant Instrument: drop a sound on a player and play it across the keyboard |
| **AutoCC** | Draw Dynamics with AutoCC on any clip: its curves drawn into the clip's controller lanes |
| **DAW Battle Pass** | The ring in the toolbar: active minutes fill the tier. Its window (Window > Battle Pass): quests to claim or reroll, the check-in calendar, crates, tokens, ideas to put at the caret, gear, the shop and daily deals, stats. Saved in Application Support |
| **Instrument Creator** | Played by > Instrument Creator: its nineteen instruments, Surprise Me, its parts |
| **Transient Shuffler** | Played by > Transient Shuffler: drop sounds A and B; MIDI plays the result |
| **Midi Evolver** | Devices > Add > Midi Evolver: hold a chord and it grows; Insert the Take, Record, Panic |
| **MIDI Production Center** | Devices > Add: Load the Clip chops it onto the sixteen pads; Transfer to Pads; its effects |
| **Reverberator** | Devices > Add, as an insert (the hall is the stage's reverb; the old Reverb return is kept in older songs but no longer heard) |
| **Midular** | Devices > Add > Midular: Load the Clip makes the chosen clip its phrase, which a key plays back; its modes, warp, envelope and filter |
| **Reese Basser** | Played by > Reese Basser: its eight engines, filter, modulation and effects |

## Not built yet

- **VST3 instruments.** Audio Units are hosted; on the Mac every instrument
  sold as VST3 ships as an Audio Unit too, and hosting VST3 would add
  Steinberg's SDK (`docs/STAGE.md`).
- **Audio Unit effects** in a player's chain: instruments only, so far.
- **VST3 or Audio Unit versions of the devices.** They are C now, which is
  what a plug-in wrapper needs; the wrapper is not written.
- **Devices are not bypassed or automated**, and @gfx is not run: a device's
  own window is replaced by its sliders.

## Not tried

This was written on Linux and built only by CI. CI does open the real app on
an Apple silicon Mac, load a composed song into it and save pictures of the
window (piano roll and score), and the first of those showed the song, its
chords lane, the Blocks bar and the inspector as intended (the inspector has
since become the menus). Nobody has yet
clicked through it, heard it through speakers or played it from a MIDI
keyboard; the first person to do so will find what the tests could not.
