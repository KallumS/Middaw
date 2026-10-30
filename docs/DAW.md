# The DAW

Middaw is a native Mac app for Apple silicon: a DAW that is generative from
the first screen. Describe the music and it is written as five parts on five
tracks, or start from an ensemble and write it yourself. Either way it stays
MIDI - notes you can see, edit, hear, engrave and export - and every
generator works on what is already there.

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

Compose uses Python, which comes with Apple's Command Line Tools
(`xcode-select --install`); everything else is in the app.

## How it is built

```
mac/Package.swift            a Swift package: no Xcode project, no dependencies
mac/Sources/MiddawCore/      the song, undo, editing, keys, MIDI files
mac/Sources/MiddawEngines/   the family's Lua, in JavaScriptCore
mac/Sources/MiddawAudio/     Core Audio: instruments, sequencer, reverb, bounce; Core MIDI
mac/Sources/Middaw/          the app: SwiftUI windows, documents, menus
mac/Tests/                   XCTest, run by CI on Apple silicon
runtime/                     Lua 5.4 and EEL2, the runtimes the family's code runs in
family/                      the family's engines and devices, unchanged
middaw/                      the composer (Python), bundled for Compose
```

- **Documents.** Each song is a macOS document: its own window, Open Recent,
  autosave and versions, and Edit > Undo named for what it undoes. `.middaw`
  files from the browser version open unchanged; a `.mid` opens as a song.
- **The family's code runs unchanged.** Good Idea, Midi Suggester, Midi
  Variator, Starting Blocks (and its notation), Midi Catalogue, DAW Battle
  Pass and Orchestration Helper are Lua; they run in Middaw's Lua 5.4
  (`runtime/lua/`, held byte for byte to the real Lua by the tests) inside
  JavaScriptCore, which every Mac has. AutoCC runs from its own JSFX through
  `runtime/jsfx/`.
- **The sound is native.** One Core Audio source node renders every track
  sample-accurately from the audio clock; nothing on that thread allocates or
  waits. Middaw Synth's eighteen presets, the drum kit and the Instant
  Instrument are ported from the browser version operation for operation.
- **What CI checks** on a real Apple silicon Mac: the MIDI writer byte for
  byte against `middaw/midi.py`, every key's spelling and signature against
  the ScaleView port, the model, every generator through JavaScriptCore,
  every preset and the kit making sound, notes starting on their beat to the
  sample, mute and solo, the loop, the reverb, and the bundle itself.

## Where the family lives

| Project | Where it is |
| --- | --- |
| **Middaw** (the composer) | Generate > Compose: a sentence becomes the song's five parts, key, tempo and meter |
| **ScaleView** | The key display in the toolbar, the chords lane, every chord name |
| **Good Idea** | Generate > Idea: an idea is a number; the same number always gives the same idea |
| **Midi Suggester** | Generate > Suggest, or Suggest… on a clip: the part that goes with it, on a new track beside it (Miderator 0040) |
| **Midi Variator** | Generate > Vary, or Vary… on a clip: variations, each saying what it changed |
| **Starting Blocks** | The Blocks bar over the piano roll: click to hear, double-click to put it at the caret, which moves on |
| **Starting Blocks Notation** | The Score tab, a part or the full score, dark or a light page |
| **Midi Catalogue** | Browser > Ideas; its instruments are every track's Instrument; its Shape It is Transform |
| **Noterator** | The ensembles (String Quartet, Big Band, Beat Maker…) and the adapters every engine is driven through |
| **Miderator** | The placement rules: into the chosen bars, else at the caret; fitted to the instrument; heard on piano or kit first |
| **Orchestration Helper** | The inspector's About, and Browser > Guide |
| **Instant Virtual Instrument** | Played by > Instant Instrument: drop a sound on a track and play it across the keyboard |
| **AutoCC** | Draw Dynamics with AutoCC on any clip: its curves drawn into the clip's controller lanes |
| **DAW Battle Pass** | The ring in the toolbar: active minutes fill the tier; saved in Application Support |
| **Reverberator, Midi Evolver, MIDI Production Center, Instrument Creator, Transient Shuffler** | Not in the native app yet: see below |

## Not built yet

- **The family's JSFX as live devices.** In the browser version Instrument
  Creator, Transient Shuffler, Midi Evolver, MIDI Production Center and
  Reverberator ran in the audio thread. A JavaScriptCore context is not safe
  to call from Core Audio's thread, so natively they need a render-ahead
  thread per chain; until then the reverb return is Middaw's own (Freeverb's
  design) and the others are absent. AutoCC works offline, as above.
- **The composer in Swift.** Compose still runs the Python composer, which
  needs the Command Line Tools. Porting it is the way to drop that.
- **Battle Pass quests, loot and the shop** have no window yet; the ring,
  tier, level, XP and notices do.
- **Score rests.** Starting Blocks Notation writes each note up to the next
  onset, so a rest inside a phrase prints as a longer note.

## Not tried

This was written on Linux and built only by CI. CI does open the real app on
an Apple silicon Mac, load a composed song into it and save pictures of the
window (piano roll and score), and the first of those showed the song, its
chords lane, the Blocks bar and the inspector as intended. Nobody has yet
clicked through it, heard it through speakers or played it from a MIDI
keyboard; the first person to do so will find what the tests could not.
