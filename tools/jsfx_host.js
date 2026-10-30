#!/usr/bin/env node
/* A headless host for Middaw's JSFX runtime that speaks the same commands as
 * the family's ysfx hosts (Midi Evolver's tools/host.cpp), so the family's own
 * engine checks run unchanged against Middaw:
 *
 *   python3 Midi-Evolver/tools/enginecheck.py   (with HOST pointing here)
 *
 *   node tools/jsfx_host.js "family/devices/Midi Evolver.jsfx" < commands
 *
 * The window commands (size, mouse, key, menu, shot, log) are accepted and do
 * nothing: Middaw does not run @gfx. `frame` runs one audio block, as the
 * ysfx host does after drawing. */
'use strict';
const fs = require('fs');
const path = require('path');
const readline = require('readline');
const J = require(path.join(__dirname, '..', 'runtime', 'jsfx', 'jsfx.js'));

const file = process.argv[2];
if (!file) { console.error('usage: jsfx_host.js fx.jsfx < commands'); process.exit(1); }
const dir = path.dirname(file);
const BS = 256, SR = 48000;
function make() {
  const fx = new J.JSFX(fs.readFileSync(file, 'utf8'), { readImport: (n) => fs.readFileSync(path.join(dir, n), 'utf8') });
  fx.init(SR);
  return fx;
}
let fx = make();
let pending = [], sent = [], clock = 0;
let play = 0, beat = 0, bpm = 120, num = 4, den = 4, frames = 0;
const zero = [new Float32Array(BS), new Float32Array(BS)];
const outs = [new Float32Array(BS), new Float32Array(BS)];
function block() {
  fx.setTime({ tempo: bpm, playState: play, beat: beat, seconds: beat * 60 / bpm, num: num, den: den });
  const midi = pending.map((d) => ({ offset: 0, data: d }));
  pending = [];
  const out = fx.process(BS, zero, outs, midi);
  for (const m of out) sent.push([clock + m.offset, m.data[0], m.data[1] || 0, m.data[2] || 0]);
  clock += BS;
  if (play === 1 || play === 5) beat += BS / SR * bpm / 60;
}
for (let b = 0; b < 4; b++) block();

const lines = [];
const out = (s) => process.stdout.write(s + '\n');
const rl = readline.createInterface({ input: process.stdin });
rl.on('line', (line) => {
  const a = line.trim().split(/\s+/);
  const cmd = a[0];
  if (!cmd || cmd[0] === '#') return;
  const n = (i, d) => (a[i] === undefined ? d : Number(a[i]));
  switch (cmd) {
    case 'slider': fx.setSlider(n(1), n(2)); break;
    case 'setvar': fx.setVar(a[1], n(2)); break;
    case 'note': pending.push([0x90 | ((n(3, 1) - 1) & 15), n(1), n(2)]); break;
    case 'noteoff': pending.push([0x80 | ((n(2, 1) - 1) & 15), n(1), 0]); break;
    case 'cc': pending.push([0xB0 | ((n(3, 1) - 1) & 15), n(1), n(2)]); break;
    case 'transport': play = n(1); beat = n(2); break;
    case 'tempo': bpm = n(1); num = n(2); den = n(3); break;
    case 'block': for (let i = 0; i < n(1); i++) block(); break;
    case 'midi':
      for (const m of sent) out('MIDI ' + m.join(' '));
      sent = []; out('ENDMIDI'); break;
    case 'frame': block(); frames++; out('FRAME ' + frames); break;
    case 'var': out('VAR' + a.slice(1).map((nm) => ' ' + nm + '=' + Number(fx.getVar(nm).toPrecision(10))).join('')); break;
    case 'mem': {
      const vals = [];
      for (let i = 0; i < n(2); i++) vals.push(Number(fx.rd(n(1) + i).toPrecision(10)));
      out('MEM' + vals.map((x) => ' ' + x).join('')); break;
    }
    case 'menutext': out('MENU '); break;
    case 'shot': out('SHOT 0 0'); break;
    case 'log': out('ENDLOG'); break;
    case 'sync': out('SYNC'); break;
    case 'wait': break;
    case 'reload': {
      const st = fx.serialize();
      fx = make();
      fx.deserialize(st);
      for (let b = 0; b < 4; b++) block();
      break;
    }
    default: break;   // size, mouse, key, menu: the window is not run
  }
});
