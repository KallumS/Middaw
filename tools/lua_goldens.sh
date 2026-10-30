#!/bin/sh
# Regenerate the real-Lua outputs that tests/js/test_lua.js compares against.
# Needs a Lua 5.4 interpreter: `brew install lua`, `apt install lua5.4`, or
# build one from any Lua 5.4 source tree. LUA=/path/to/lua5.4 to choose.
set -e
cd "$(dirname "$0")/.."
LUA=${LUA:-lua5.4}
"$LUA" tests/js/lua/conformance.lua > tests/js/lua/conformance.expected
"$LUA" tests/js/lua/engines_golden.lua family/engines/ > tests/js/lua/engines.expected
echo "goldens written with $("$LUA" -v 2>&1 | head -1)"
