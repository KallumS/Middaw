/* runtime/polyfill.js: JavaScriptCore's missing TextEncoder/TextDecoder,
 * held to Node's own on the strings Lua actually passes through. */
'use strict';
const test = require('node:test');
const assert = require('node:assert');
require('../../runtime/polyfill.js');
const U = globalThis.MiddawUTF8;

const SAMPLES = ['', 'plain ascii', 'Détaché — Violin I', 'Cb Major ♭♯', '𝄞 treble', 'Ünïcödé ✓ 音楽', '\u0000\u007f\u0080߿ࠀ￿'];

test('encodes as Node does', () => {
  for (const s of SAMPLES) assert.deepStrictEqual(Array.from(new U.TextEncoder().encode(s)), Array.from(new TextEncoder().encode(s)), s);
});

test('decodes as Node does, valid or not', () => {
  for (const s of SAMPLES) assert.strictEqual(new U.TextDecoder().decode(new TextEncoder().encode(s)), s);
  const bad = [[0xff], [0xc0, 0x80], [0xe0, 0x80, 0x80], [0xed, 0xa0, 0x80], [0xf4, 0x90, 0x80, 0x80], [0xe2, 0x82], [0x41, 0xe2, 0x82, 0x42],
               [0xf0, 0x9d, 0x84, 0x9e, 0x80], [0xc3]];
  for (const b of bad) {
    assert.strictEqual(new U.TextDecoder().decode(new Uint8Array(b)), new TextDecoder().decode(new Uint8Array(b)), b.join(' '));
  }
});

test('random bytes decode as Node decodes them', () => {
  let seed = 7;
  const rnd = () => (seed = (seed * 1103515245 + 12345) & 0x7fffffff) / 0x7fffffff;
  for (let k = 0; k < 2000; k++) {
    const b = new Uint8Array(1 + Math.floor(rnd() * 12)).map(() => Math.floor(rnd() * 256));
    assert.strictEqual(new U.TextDecoder().decode(b), new TextDecoder().decode(b), Array.from(b).join(' '));
  }
});
