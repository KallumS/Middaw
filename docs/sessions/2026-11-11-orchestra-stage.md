# 2026-11-11 — the window becomes an orchestra stage

Asked for by the user: replace the track-based workflow with an orchestra
layout. Every player's position is a slot for a plug-in (click the Oboe seat,
choose the oboe); each position gets the right panning and convolution
reverb (violins close and to the side, timpani further away); anything that
is not an orchestra - synths, drum machines - goes at the front, dry and in
the middle, as many as wanted. The editing area underneath has MIDI,
notation, drums and a step sequencer. All of `docs/` was read first, and
other software looked at (`docs/STAGE.md`, "Where it came from").

## What changed

- `MiddawCore/Stage.swift`: 41 seats in American seating, three halls,
  `Stage.sound` (direct sound, air, image-method reflections) and
  `Stage.tail` (the hall's late reverberation, levelled by the critical
  distance). `Track.seat`, `Project.hall`, song version 2; an older song is
  seated when it opens. `Device.plugin` names an Audio Unit.
- `MiddawAudio`: `Convolver` (zero-latency partitioned FFT convolution),
  `SeatVoice` and `HallTail` in the renderer; `PluginHost` and
  `PluginInstance` host Audio Unit instruments inside the renderer's block.
  The Freeverb return is gone; the hall is the reverb.
- The app: `StageView` (seats, the front, the hall, the sound menu,
  plug-in windows), the arrange view reduced to the chosen players' part
  lane, `PartEditors.swift` (Drums and the Step Sequencer), the editor's
  tabs MIDI, Notation, Drums, Step Sequencer with Devices beside them, the
  inspector's seat picker, the mixer removed (level, mute and solo are on
  the player). Ensembles, the browser and Compose seat orchestral players;
  a band plays at the front.

## Decisions

- **Audio Units, not VST3.** Core Audio hosts them with nothing added; every
  Mac instrument sold as VST3 ships as an Audio Unit too. VST3 would need
  Steinberg's SDK.
- **Calculated rooms, not recorded ones.** No impulse response in the repo
  was recorded anywhere, so none needs clearing; the numbers come from the
  seats' coordinates, the halls' sizes and Sabine.
- **One tail for the stage.** A diffuse tail is the same from every seat;
  only its level beside the direct sound changes, which the distance already
  gives. Per-seat convolution is the sparse direct sound and reflections.

## Checked

- Python and JavaScript: 242 tests pass (nothing there changed).
- Swift: written on Linux without a compiler; CI on the Mac is the first
  build. New tests: the seating and halls (`StageTests`), the convolver
  against the convolution sum, the front dry and centred, seats panned and
  distanced, the studio drier than the hall, Apple's DLS synth as an Audio
  Unit in a seat.

## Not tried

Nobody has listened to the halls on speakers, or opened a third-party
library in a seat.
