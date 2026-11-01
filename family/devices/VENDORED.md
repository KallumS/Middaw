# The devices, and where they came from

Every .jsfx and .jsfx-inc here is copied **unchanged** from the family's
repositories and runs in Middaw's JSFX runtime (`runtime/jsfx/jsfx.js`): the same
@init, @slider, @block, @sample and @serialize code REAPER runs. Middaw draws
each device's controls from its sliders instead of running @gfx. Fix a device
in its own repository and copy it here.

| File | Repository | Commit |
| --- | --- | --- |
| AutoCC.jsfx | KallumS/AutoCC | df76ac4 |
| Midi Evolver.jsfx | KallumS/Midi-Evolver | 66a174b (branch `claude/stuck-note-end-of-block`, not yet merged) |
| MIDI_Production_Center.jsfx, mpc_*.jsfx-inc | KallumS/MIDI-Production-Center | 29dfb37 |
| Reverberator.jsfx | KallumS/Reverberator | 47bcf8c |
| Instrument-Creator.jsfx | KallumS/Instrument-Creator | fd7dcdd |
| TransientShuffler.jsfx | KallumS/Transient-Shuffler | 30ca451 |

`tests/family/midi_evolver_enginecheck.py` is Midi Evolver's own engine check
(same commit), run unchanged through `tools/jsfx_host.js`, and through
`tools/jsfx_c_host.c` over the same device compiled to C: 78 of 78 pass.

**Fixed in Midi Evolver** (its decision 0009, 30-31 October 2026): about one
run in six, one of the "nothing hanging" checks used to fail with a note-off
"with nothing sounding". A note struck in a block's last sample and ended in
the same block had its note-off clamped onto its note-on's offset and sorted
first. The engine check now sweeps sixty locked variations for it.
