# The devices, and where they came from

Every .jsfx and .jsfx-inc here is copied **unchanged** from the family's
repositories and runs in Middaw's JSFX runtime (`runtime/jsfx/jsfx.js`): the same
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
(same commit), run unchanged through `tools/jsfx_host.js`, and through
`tools/jsfx_c_host.c` over the same device compiled to C: 77 of 77 pass.

**A bug to fix in Midi Evolver** (found here, 30 October 2026). About one run
in six, one of the "nothing hanging" checks fails with a note-off "with nothing
sounding". It is the device, not the runtime: both runtimes do it identically,
and it reproduces every time with `JSFX_SEED=126 JSFX_CLOCK=samples` on the
chord-change check. A note struck within two samples of a block's end and ended
in the same block gets its note-off at `a[6] + 2 * bps`, which `to_off` clamps
back to the block's last sample, the same as the note-on; the queue's sort then
puts note-offs before note-ons at one offset, so the note-off goes out first
and the note sounds until the next chord. `an_end`'s comment says the two
samples are there to stop exactly this; the clamp defeats them at the end of a
block. Carrying such a note-off into the next block (`schedule`) would fix it.
