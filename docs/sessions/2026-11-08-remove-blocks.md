# 2026-11-08 — ScaleView Pro's Starting Blocks dictionary comes back out

ScaleView Pro reversed its decision 0011 (f13f8a6, 1.3.0): Starting Blocks'
chord list no longer decides which roots a chord can have, because a list of
complete chords cannot see a note left out (a Cmaj13 without its 11th read
`Amin11/C`, a Cmin9 shell `A#add9Add11/C`, C7sus2 `A#add9/C`). The user asked
for every copy of the reader to follow.

## What changed

- `middaw/scaleview.py` and `runtime/composer/core.js`: the Blocks tables and
  the branch that used them are gone. The other four changes f93d973 brought
  in with them (dim9 and two-note chords, the doubled-root rule, both fifths
  costed, the altered-dominant and slash tiebreaks) stay.
- `family/engines/`: `ms_theory.lua` and `mv_theory.lua` from Midi Suggester
  3d5b911 and Midi Variator 4a858ef, the same removal there.
- `tests/test_scaleview.py` follows Pro's Lua suite at f13f8a6: six pins back
  to their earlier names, the Blocks section replaced by Pro's five new pins
  for the names 0011 got wrong, and the five maj7sus2 pins added since.
  `TestKeyChords` now says the key spells and does not choose.

## Checked

- **Against Pro itself.** 53,472 voicings (every 1-7 note set on every bass,
  plain and with the bass or the top note doubled) in no key and seven keys,
  named by Pro's `tools/runner.lua` and by a dumper for each port: 427,776
  names, byte-identical for the Python and for the JavaScript. The same rig
  finds 25,824 differences against `main`'s Python and JavaScript, which is
  exactly what it finds against Pro with the dictionary.
- **The case list.** Pro's suite was run instrumented to record every
  `expect` with its key; Middaw's list matches it case for case (117), less
  the three Simplify Note Names cases, as before. The same converter run on
  Pro's suite at df4ea43 reproduces `main`'s list the same way.
- The whole suite: 242 tests pass; `tests/test_scaleview.py` fails 14 on
  `main`'s port. The Lua goldens and the Swift fixtures regenerate
  byte-identical, so no engine check and no composed chord changes.
- **Real music**, re-measured with both readers on the same checkouts: When in
  Rome 64.3% -> 64.1% same root (118 of 52,685), 58.6% -> 58.2% root and
  quality; music21 chorales 80.2% -> 80.5% (three of 1,041). The old reader
  reproduces the figures recorded on 1 November exactly. Key detection and
  every melody figure are unchanged.

## Left alone

- The Swift app is not built here; nothing Swift changed and its fixtures
  are identical. CI will say.
- The two Lua engines are vendored from branches awaiting merge in their own
  repositories; `VENDORED.md` says which.
