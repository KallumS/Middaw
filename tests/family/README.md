# The family's own checks, run against Middaw

Each file here is copied **unchanged** from a family repository. They were
written to drive the plug-in in ysfx, REAPER's EEL2 engine; here they drive it
in Middaw's JSFX runtime through `tools/jsfx_host.js`, which speaks the same
commands. A check that passes here passes for the same reason it passes there.

| File | From | Commit |
| --- | --- | --- |
| `midi_evolver_enginecheck.py` | KallumS/Midi-Evolver `tools/enginecheck.py` | see web/devices/VENDORED.md |
