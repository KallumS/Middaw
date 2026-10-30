/* Middaw's Lua against the real Lua 5.4.
 *
 * Each .expected file is what lua5.4 printed for the .lua file beside it
 * (tools/lua_goldens.sh regenerates them). Middaw's Lua must print the same
 * bytes: the conformance script covers the language and library, and
 * engines_golden.lua drives every family engine through every setting. */
'use strict';
const test = require('node:test');
const assert = require('node:assert');
const { execFileSync } = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');

const ROOT = path.join(__dirname, '..', '..');
function run(script, args) {
  return execFileSync(process.execPath, [path.join(ROOT, 'tools', 'lua.js'), script].concat(args || []),
    { cwd: ROOT, encoding: 'latin1', maxBuffer: 64 * 1024 * 1024 });
}
function expected(name) {
  return fs.readFileSync(path.join(ROOT, 'tests', 'js', 'lua', name), 'latin1');
}

test('the language and the library print what Lua 5.4 prints', () => {
  assert.strictEqual(run('tests/js/lua/conformance.lua'), expected('conformance.expected'));
});

test('every engine, every setting, every seed: the same notes as Lua 5.4', () => {
  const mine = run('tests/js/lua/engines_golden.lua', ['web/engines/']).split('\n');
  const real = expected('engines.expected').split('\n');
  for (let i = 0; i < Math.max(mine.length, real.length); i++) {
    if (mine[i] !== real[i]) assert.fail('line ' + (i + 1) + ' differs\n  lua5.4: ' + real[i] + '\n  middaw: ' + mine[i]);
  }
});
