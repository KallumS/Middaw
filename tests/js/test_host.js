/* runtime/host.js: the engines as the native app speaks to them, JSON in and out. */
'use strict';
const test = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');

const ROOT = path.join(__dirname, '..', '..');
require(path.join(ROOT, 'runtime', 'lua', 'lua_parse.js'));
require(path.join(ROOT, 'runtime', 'lua', 'lua_runtime.js'));
require(path.join(ROOT, 'runtime', 'lua', 'lua_compile.js'));
require(path.join(ROOT, 'runtime', 'host.js'));
const H = globalThis.MiddawHost;
// The bytes as one character each, as the native side hands them over.
H.init((p) => fs.readFileSync(path.join(ROOT, 'family', 'engines', p)).toString('latin1'));

function call(method, args) {
  const r = JSON.parse(H.call(method, args === undefined ? '' : JSON.stringify(args)));
  if (!r.ok) throw new Error(method + ': ' + r.error);
  return r.value;
}
const C_MAJOR = { root: 1, scale: 1 };

test('every generator is offered, with its settings', () => {
  const ids = call('generators').map((g) => g.id);
  for (const id of ['good-idea', 'midi-suggester', 'midi-variator', 'starting-blocks', 'midi-catalogue']) assert.ok(ids.includes(id), id);
});

test('Starting Blocks gives a block per degree of the key, with notes', () => {
  const s = call('newSession', { generator: 'starting-blocks' });
  call('useKey', { session: s, key: C_MAJOR });
  const ctx = { root: 1, scale: 1, num: 4, den: 4, barBeats: 4, bpm: 120, inst: 'pno', catalogueId: 'pno', bars: 1,
                selection: { notes: [], beats: 0, drums: false } };
  const settings = call('settings', { session: s, context: ctx });
  assert.ok(settings.some((x) => x.id === 'cat'));
  const r = call('generate', { session: s, context: ctx, seed: 1, count: 12 });
  assert.strictEqual(r.results.length, 7);
  assert.ok(r.results[0].parts[0].notes.length >= 3);
  assert.ok(Array.isArray(r.results[0].parts[0].notes));
});

test('Good Idea is deterministic: the same number gives the same idea', () => {
  const ctx = { root: 1, scale: 1, num: 4, den: 4, barBeats: 4, bpm: 120, inst: 'pno', catalogueId: 'pno', bars: 4,
                selection: { notes: [], beats: 0, drums: false } };
  const a = call('newSession', { generator: 'good-idea' }), b = call('newSession', { generator: 'good-idea' });
  const x = call('generate', { session: a, context: ctx, seed: 4182, count: 2 });
  const y = call('generate', { session: b, context: ctx, seed: 4182, count: 2 });
  assert.deepStrictEqual(x, y);
  assert.ok(x.results.length >= 1);
});

test('chords are named by ScaleView, notes spelled for the key', () => {
  assert.strictEqual(call('nameChord', { pitches: [60, 64, 67, 70], key: C_MAJOR }), 'C7');
  assert.strictEqual(call('nameChord', { pitches: [57, 60, 64], key: C_MAJOR }), 'Amin');
  assert.strictEqual(call('noteNames', { key: { root: 16, scale: 1 } })[10], 'Bb');
});

test('the orchestra and the orchestration guide load', () => {
  const inst = call('instruments');
  assert.ok(inst.length > 25);
  assert.ok(inst.find((i) => i.id === 'vln1' && i.low !== undefined));
  const o = call('orchestration');
  assert.ok(o.entries.length > 100);
});

test('a part is engraved as pen calls the native side can replay', () => {
  const notes = [0, 1, 2, 3].map((i) => ({ start: i, len: 1, pitch: 60 + 2 * i, vel: 100 }));
  const r = call('engrave', { key: C_MAJOR, meter: [4, 4], barBeats: 4, beats: 4, notes, width: 60, space: 8 });
  assert.ok(r.height > 0);
  const kinds = new Set(r.ops.map((o) => o[0]));
  assert.ok(kinds.has('line') && kinds.has('poly'), [...kinds].join());
  for (const o of r.ops) for (const v of o.slice(1)) if (typeof v === 'number') assert.ok(Number.isFinite(v));
});

test('the Battle Pass starts, counts what you do and saves as its own text', () => {
  call('passStart', { epoch: 1790000000, clock: 0 });
  call('passCall', { fn: 'event', args: ['$state', '$session', 'track', 1] });
  const saved = call('passSave');
  assert.strictEqual(typeof saved, 'string');
  call('passStart', { epoch: 1790000100, clock: 0, saved });
  assert.ok(call('passGet', { path: 'xp' }) !== undefined || call('passGet', { path: 'level' }) !== undefined);
});

test('an error comes back as text, not a crash', () => {
  const r = JSON.parse(H.call('newSession', JSON.stringify({ generator: 'nope' })));
  assert.strictEqual(r.ok, false);
  assert.match(r.error, /nope/);
});
