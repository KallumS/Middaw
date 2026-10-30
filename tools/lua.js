#!/usr/bin/env node
/* Run a Lua file with Middaw's Lua, the way `lua5.4 file.lua args` would:
 *   node tools/lua.js script.lua [args...]
 * Files are read and written relative to the current directory, so engines
 * that dofile() their neighbours work as they do under the real Lua. */
'use strict';
const fs = require('fs');
const path = require('path');
const root = path.join(__dirname, '..', 'web', 'lua');
require(path.join(root, 'lua_parse.js'));
require(path.join(root, 'lua_runtime.js'));
const L = require(path.join(root, 'lua_compile.js'));

const file = process.argv[2];
if (!file) { console.error('usage: node tools/lua.js file.lua [args]'); process.exit(1); }
const out = [];
const env = L.makeEnv({
  print: (s) => out.push(s + '\n'),
  write: (s) => out.push(s),
  readFile: (p) => { try { return fs.readFileSync(p, 'latin1'); } catch (e) { return null; } },
  writeFile: (p, d) => fs.writeFileSync(p, Buffer.from(d, 'latin1')),
  removeFile: (p) => { try { fs.unlinkSync(p); return true; } catch (e) { return false; } },
});
const argt = new L.LuaTable();
argt.set(0, L.toBytes(file));
process.argv.slice(3).forEach((a, i) => argt.set(i + 1, L.toBytes(a)));
env.set('arg', argt);
let code = 0;
try {
  L.load(fs.readFileSync(file, 'latin1'), file, env)(...process.argv.slice(3).map(L.toBytes));
} catch (e) {
  out.push('lua: ' + L.errorValue(e) + '\n');
  if (process.env.LUA_JS_STACK) out.push(String(e.stack) + '\n');
  code = 1;
}
process.stdout.write(Buffer.from(out.join(''), 'latin1'));
process.exitCode = code;
