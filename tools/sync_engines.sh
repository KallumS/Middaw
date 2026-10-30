#!/bin/sh
# Copy the family's Lua engines into web/engines/, unchanged.
#   tools/sync_engines.sh ../repos     (a folder holding the repositories)
# Then update web/engines/VENDORED.md and run tools/lua_goldens.sh.
set -e
SRC=${1:?folder holding Good-Idea, Midi-Catalogue, ... checkouts}
DST="$(dirname "$0")/../web/engines"
cp "$SRC/Good-Idea/reascripts/gi_theory.lua" "$SRC/Good-Idea/reascripts/gi_idea.lua" "$DST/good-idea/"
cp "$SRC/Midi-Catalogue/reascripts/mc_theory.lua" "$SRC/Midi-Catalogue/reascripts/mc_orchestra.lua" \
   "$SRC/Midi-Catalogue/reascripts/mc_catalogue.lua" "$DST/midi-catalogue/"
for f in ms_theory ms_read ms_harmony ms_melody; do cp "$SRC/Midi-Suggester/reascripts/$f.lua" "$DST/midi-suggester/"; done
cp "$SRC/Midi-Variator/reascripts/mv_theory.lua" "$SRC/Midi-Variator/reascripts/mv_vary.lua" "$DST/midi-variator/"
cp "$SRC/Starting-Blocks-Notation/reascripts/sb_engine.lua" "$DST/starting-blocks/"
cp "$SRC/Noterator/Engines/adapters/"*.lua "$DST/adapters/"
for f in sb_notate.lua sb_draw.lua sb_glyphs.lua sb_glyphs-OFL.txt; do cp "$SRC/Starting-Blocks-Notation/reascripts/$f" "$DST/notation/"; done
for f in bp_game bp_loot bp_theory; do cp "$SRC/DAW-Battle-Pass/reascripts/$f.lua" "$DST/battle-pass/"; done
cp "$SRC/Orchestration-Helper/orchestration_data.lua" "$SRC/Orchestration-Helper/orchestration_composers.lua" "$DST/orchestration/"
for r in Good-Idea Midi-Catalogue Midi-Suggester Midi-Variator Starting-Blocks-Notation Noterator DAW-Battle-Pass Orchestration-Helper; do
  echo "$r $(git -C "$SRC/$r" rev-parse --short HEAD)"
done
