# The engines, and where they came from

Everything here except this file is copied **unchanged** from the family's
own repositories and runs in Middaw's Lua (`runtime/lua/`), exactly as it runs in
REAPER, Miderator and Noterator. Do not edit these files here: fix them in
their own repository, then run `tools/sync_engines.sh` and update this table.

| Folder | Repository | Commit | Files |
| --- | --- | --- | --- |
| `good-idea/` | KallumS/Good-Idea | 91500c5 | gi_theory.lua, gi_idea.lua |
| `midi-catalogue/` | KallumS/Midi-Catalogue | 4eb91a8 | mc_theory.lua, mc_orchestra.lua, mc_catalogue.lua |
| `midi-suggester/` | KallumS/Midi-Suggester | 2eb02f1 | ms_theory.lua, ms_read.lua, ms_harmony.lua, ms_melody.lua |
| `midi-variator/` | KallumS/Midi-Variator | f72b39d | mv_theory.lua, mv_vary.lua |
| `starting-blocks/` | KallumS/Starting-Blocks-Notation | 0d46479 | sb_engine.lua (identical to Starting Blocks') |
| `adapters/` | KallumS/Noterator | 7fe17e4 | common.lua and one adapter per engine, shared with Miderator |
| `notation/` | KallumS/Starting-Blocks-Notation | 0d46479 | sb_notate.lua, sb_draw.lua, sb_glyphs.lua, sb_glyphs-OFL.txt (the glyphs' licence) |
| `battle-pass/` | KallumS/DAW-Battle-Pass | 16dac8d | bp_game.lua, bp_loot.lua, bp_theory.lua |
| `orchestration/` | KallumS/Orchestration-Helper | 3bff05f | orchestration_data.lua, orchestration_composers.lua |

The score view engraves with `notation/` (a part as Starting Blocks Notation
would print a block), the Battle Pass runs `battle-pass/` and saves through
Middaw's server, and the inspector's "About" and the browser's Guide read
`orchestration/`.

`tests/js/lua/engines.expected` is what the real Lua 5.4 prints when
`tests/js/lua/engines_golden.lua` drives every adapter through every setting;
`tests/js/test_lua.js` holds Middaw's Lua to it byte for byte. After a sync,
regenerate it with `tools/lua_goldens.sh` (needs a Lua 5.4).
