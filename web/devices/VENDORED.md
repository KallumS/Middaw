# The devices, and where they came from

Every .jsfx and .jsfx-inc here is copied **unchanged** from the family's
repositories and runs in Middaw's JSFX runtime (`web/jsfx/jsfx.js`): the same
@init, @slider, @block, @sample and @serialize code REAPER runs. Middaw draws
each device's controls from its sliders instead of running @gfx. Fix a device
in its own repository and copy it here.

| File | Repository | Commit |
| --- | --- | --- |
| AutoCC.jsfx | KallumS/AutoCC | 0662344 |
| Midi Evolver.jsfx | KallumS/Midi-Evolver | f56c61b |
| MIDI_Production_Center.jsfx, mpc_*.jsfx-inc | KallumS/MIDI-Production-Center | 676ead3 |
| Reverberator.jsfx | KallumS/Reverberator | a2e8bee |
| Instrument-Creator.jsfx | KallumS/Instrument-Creator | 5e5f1fb |
| TransientShuffler.jsfx | KallumS/Transient-Shuffler | 5870594 |

`tests/family/midi_evolver_enginecheck.py` is Midi Evolver's own engine check
(same commit), run unchanged through `tools/jsfx_host.js`: 77 of 77 pass.
