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

test('a silence inside a phrase is engraved as a rest, articulation is not', () => {
  // Starting Blocks Notation's opts.rests (its decision 0019): a clip is as
  // played, not a gated block, so its rests are part of the music.
  const draw = (lens) => JSON.stringify(call('engrave', { key: C_MAJOR, meter: [4, 4], barBeats: 4, beats: 4, width: 60, space: 8,
    notes: lens.map((len, i) => ({ start: i, len, pitch: 67, vel: 100 })) }).ops);
  const legato = draw([1, 1, 1, 1]);
  assert.notStrictEqual(draw([1, 0.5, 1, 1]), legato, 'the eighth rest was drawn as a longer note');
  assert.strictEqual(draw([0.9, 0.9, 0.85, 0.95]), legato, 'articulation was drawn as rests');
});

test('the Battle Pass starts, counts what you do and saves as its own text', () => {
  call('passStart', { epoch: 1790000000, clock: 0 });
  call('passCall', { fn: 'event', args: ['$state', '$session', 'track', 1] });
  const saved = call('passSave');
  assert.strictEqual(typeof saved, 'string');
  call('passStart', { epoch: 1790000100, clock: 0, saved });
  assert.ok(call('passGet', { path: 'xp' }) !== undefined || call('passGet', { path: 'level' }) !== undefined);
});

test('AutoCC draws dynamics for a clip, from its own JSFX', () => {
  require(path.join(ROOT, 'runtime', 'jsfx', 'jsfx.js'));
  const source = fs.readFileSync(path.join(ROOT, 'family', 'devices', 'AutoCC.jsfx'), 'utf8');
  const notes = [0, 1, 2, 3].map((i) => ({ start: i, len: 0.9, pitch: 60 + i, vel: 60 + 15 * i }));
  const lanes = call('autoCC', { source, notes, tempo: 100, meter: [4, 4], length: 4, sliders: { 1: 1 } });
  const nums = Object.keys(lanes);
  assert.ok(nums.length >= 1, 'some lane');
  for (const n of nums) {
    for (const [beat, value] of lanes[n]) {
      assert.ok(beat >= 0 && beat <= 4, 'beat ' + beat);
      assert.ok(value >= 0 && value <= 127, 'value ' + value);
    }
  }
});

test('an error comes back as text, not a crash', () => {
  const r = JSON.parse(H.call('newSession', JSON.stringify({ generator: 'nope' })));
  assert.strictEqual(r.ok, false);
  assert.match(r.error, /nope/);
});

test('the Battle Pass shop and rarities are read from the game itself', () => {
  call('passStart', { epoch: 1790000000, clock: 0 });
  const shop = call('passConst', { name: 'SHOP' });
  assert.ok(shop.length >= 10 && shop.every((i) => i.id && i.name && i.price > 0));
  const rarity = call('passConst', { module: 'loot', name: 'RARITY' });
  assert.deepStrictEqual(rarity.map((r) => r.name), ['Poor', 'Common', 'Uncommon', 'Rare', 'Epic', 'Legendary', 'Mythic']);
  assert.strictEqual(call('passConst', { name: 'CHECKIN' }).length, 7);
});
