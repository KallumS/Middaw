/* Middaw's JSFX runtime: EEL2 as REAPER runs it, and the family's devices. */
'use strict';
const test = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');
const J = require('../../runtime/jsfx/jsfx.js');

const DEV = path.join(__dirname, '..', '..', 'family', 'devices');
function device(name) {
  return new J.JSFX(fs.readFileSync(path.join(DEV, name), 'utf8'),
    { readImport: (n) => fs.readFileSync(path.join(DEV, n), 'utf8') });
}
// A tiny plug-in: `code` in @init, the result read back from variables.
function run(code, names) {
  const fx = new J.JSFX('desc:test\n@init\n' + code + '\n');
  fx.init(48000);
  return names.map((n) => fx.getVar(n));
}

test('EEL2 operators: precedence, near-equality, integer %, powers', () => {
  const r = run('a = 2 + 3 * 4; b = -2 ^ 2; c = 7 % 3; d = -7 % 3; e = 1 == 1.000001; f = 1 === 1.000001;' +
                'g = 10 / 4; h = 5 | 2; i = 6 & 3; j = 5 ~ 3; k = 1 << 4; l = !0; m = !0.5; n = 0.000001 ? 1 : 2;' +
                'o = 2 ^ 3 ^ 2; p = 3 > 2 && 2 > 3 || 1; q = 8 >> 1;',
                ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q']);
  assert.deepStrictEqual(r, [14, 4, 1, 1, 1, 0, 2.5, 7, 2, 6, 16, 1, 0, 2, 512, 1, 4]);
});

test('EEL2 control: sequences, ?:, loop, while, assignment as a value', () => {
  const r = run('x = (1; 2; 3); y = 0; loop(5, y += 2); i = 0; s = 0; while (i < 10) ( s += i; i += 1; );' +
                'w = 0; while (w += 1; w < 7); t = 1 ? (u = 9; 10) : 20; z = (q = 4) + 1; c = 0 ? 5;',
                ['x', 'y', 's', 'w', 't', 'u', 'z', 'q', 'c']);
  assert.deepStrictEqual(r, [3, 10, 45, 7, 10, 9, 5, 4, 0]);
});

test('EEL2 functions: parameters by value, locals that keep their value', () => {
  const r = run('function sq(x) ( x * x ); function count() local(n) ( n += 1 );' +
                'function clamp(v, lo, hi) ( max(lo, min(hi, v)) );' +
                'a = sq(7); count(); count(); b = count(); c = clamp(15, 0, 10); d = clamp(-3, 0, 10);',
                ['a', 'b', 'c', 'd']);
  assert.deepStrictEqual(r, [49, 3, 10, 0]);
});

test('EEL2 memory: indexing, compound writes, memset and memcpy, unwritten reads 0', () => {
  const r = run('buf = 1000; buf[0] = 5; buf[3] = 7; buf[3] += 1; a = buf[3]; b = buf[1]; c = 2000000[0];' +
                'memset(5000, 2, 4); memcpy(6000, 5000, 4); d = 6000[3]; e = 6000[4]; big = 4000000; big[0] = 1; f = big[];',
                ['a', 'b', 'c', 'd', 'e', 'f']);
  assert.deepStrictEqual(r, [8, 0, 0, 2, 0, 1]);
});

test('EEL2 strings: literals, named strings, sprintf and string functions', () => {
  const fx = new J.JSFX('desc:t\n@init\nsprintf(#a, "%d bars at %.1f", 4, 92.25); n = strlen(#a); strcpy(#b, "Hi"); strcat(#b, "!"); c = str_getchar(#b, 1);\n');
  fx.init(48000);
  assert.strictEqual(fx.str(fx.named('#a')), '4 bars at 92.2');
  assert.strictEqual(fx.getVar('n'), 14);
  assert.strictEqual(fx.str(fx.named('#b')), 'Hi!');
  assert.strictEqual(fx.getVar('c'), 'i'.charCodeAt(0));
});

test('MIDI: what is not read passes through; what is sent keeps its offset', () => {
  const thru = new J.JSFX('desc:t\n@block\n');
  const out = thru.process(64, null, null, [{ offset: 3, data: [0x90, 60, 100] }]);
  assert.deepStrictEqual(out, [{ offset: 3, data: [0x90, 60, 100] }]);
  const up = new J.JSFX('desc:t\n@block\nwhile (midirecv(o, m1, m2, m3)) ( midisend(o, m1, m2 + 12, m3); );\n');
  assert.deepStrictEqual(up.process(64, null, null, [{ offset: 5, data: [0x90, 60, 90] }]), [{ offset: 5, data: [0x90, 72, 90] }]);
});

test('sliders: header parsed, default set, @slider runs on change', () => {
  const fx = new J.JSFX('desc:t\nslider1:3<0,4,1{A,B,C,D,E}>-Choice\nslider2:gain=0.5<0,1,0.01>Gain\n@slider\ncopy = slider1 * 10 + gain;\n');
  fx.init(48000);
  assert.strictEqual(fx.file.sliders.length, 2);
  assert.deepStrictEqual(fx.file.sliders[0].names, ['A', 'B', 'C', 'D', 'E']);
  assert.strictEqual(fx.file.sliders[0].hidden, true);
  assert.strictEqual(fx.file.sliders[1].variable, 'gain');
  assert.strictEqual(fx.getVar('copy'), 30.5);
  fx.setSlider(1, 1); fx.process(16, null, null, []);
  assert.strictEqual(fx.getVar('copy'), 10.5);
});

test('every family device compiles and stays finite', () => {
  const chord = [60, 64, 67].map((p, i) => ({ offset: i, data: [0x90, p, 100] }));
  for (const name of fs.readdirSync(DEV).filter((f) => f.endsWith('.jsfx'))) {
    const fx = device(name);
    fx.init(48000);
    const n = 128, ins = [new Float32Array(n), new Float32Array(n)], outs = [new Float32Array(n), new Float32Array(n)];
    ins[0][0] = ins[1][0] = 1;
    for (let b = 0; b < 60; b++) {
      fx.process(n, ins, outs, b === 0 ? chord : []);
      for (const x of outs[0]) assert.ok(Number.isFinite(x), name + ' sent a non-finite sample');
      ins[0][0] = ins[1][0] = 0;
    }
  }
});

test('Instrument Creator plays a note it is sent', () => {
  const fx = device('Instrument-Creator.jsfx');
  fx.init(48000);
  const n = 128, outs = [new Float32Array(n), new Float32Array(n)];
  let peak = 0;
  for (let b = 0; b < 80; b++) {
    fx.process(n, null, outs, b === 0 ? [{ offset: 0, data: [0x90, 60, 110] }] : []);
    for (const x of outs[0]) peak = Math.max(peak, Math.abs(x));
  }
  assert.ok(peak > 0.01, 'silent: peak ' + peak);
});

test('AutoCC draws the arc: CC1 rises on a note, settles, and falls after it', () => {
  const fx = device('AutoCC.jsfx');
  fx.init(48000);
  const n = 256, cc1 = [];
  for (let b = 0; b < 600; b++) {
    const midi = b === 0 ? [{ offset: 0, data: [0x90, 60, 100] }] : (b === 300 ? [{ offset: 0, data: [0x80, 60, 0] }] : []);
    for (const m of fx.process(n, null, null, midi)) if ((m.data[0] & 0xF0) === 0xB0 && m.data[1] === 1) cc1.push([b, m.data[2]]);
  }
  assert.ok(cc1.length > 20, 'too few CC1 values: ' + cc1.length);
  const during = cc1.filter((c) => c[0] < 300).map((c) => c[1]);
  const after = cc1.filter((c) => c[0] > 300).map((c) => c[1]);
  const peak = Math.max(...during);
  assert.ok(peak >= 90, 'CC1 never swelled: peak ' + peak);
  assert.ok(during[during.length - 1] < peak, 'CC1 did not settle below its peak');
  assert.ok(after.length && after[after.length - 1] < 10, 'CC1 did not fall back after the note');
});

test('@serialize keeps a device as it was', () => {
  const a = device('Midi Evolver.jsfx');
  a.init(48000);
  a.setSlider(2, 16); a.setSlider(7, 4242);
  a.process(128, null, null, []);
  const state = JSON.parse(JSON.stringify(a.serialize()));
  const b = device('Midi Evolver.jsfx');
  b.init(48000);
  b.deserialize(state);
  b.process(128, null, null, []);
  assert.strictEqual(b.getSlider(2), 16);
  assert.strictEqual(b.getSlider(7), 4242);
});
