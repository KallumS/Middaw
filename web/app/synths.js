/* Middaw's built-in sounds, in plain JavaScript so they run in the audio
 * thread beside the JSFX devices.
 *
 *   Synth       one voice design, many presets: keys, strings, brass, reeds,
 *               flutes, plucked (Karplus-Strong), mallets (FM), organ, pads.
 *               It answers AutoCC: CC1 opens the tone, CC11 and CC7 set the
 *               level, CC64 holds.
 *   Kit         a General MIDI drum kit, every drum synthesised.
 *   Sampler     the Instant Instrument: any sound you drop on a track,
 *               played across the keyboard.
 *   Click       the metronome.
 *
 * Every instrument has the same face: noteOn, noteOff, cc, render(n, L, R).
 */
(function (NS) {
  'use strict';

  function mtof(p) { return 440 * Math.pow(2, (p - 69) / 12); }
  function clamp(x, a, b) { return x < a ? a : x > b ? b : x; }

  // ------------------------------------------------------------ presets --
  // osc: saw | square | tri | sine | fm | ks (plucked) | organ | bell
  var PRESETS = {
    keys:    { osc: 'fm', ratio: 1, index: 2.2, indexDecay: 1.6, a: 0.002, d: 1.4, s: 0.15, r: 0.35, cutoff: 9000, env: 0, detune: 0, gain: 0.55 },
    piano:   { osc: 'fm', ratio: 1, index: 1.6, indexDecay: 2.4, a: 0.002, d: 2.2, s: 0.08, r: 0.5, cutoff: 7000, env: 0, detune: 0.3, gain: 0.6, hammer: 0.15 },
    epiano:  { osc: 'fm', ratio: 1, index: 3.5, indexDecay: 3.0, a: 0.001, d: 2.0, s: 0.25, r: 0.4, cutoff: 12000, env: 0, gain: 0.5, trem: 0.15 },
    strings: { osc: 'saw', a: 0.18, d: 0.3, s: 0.9, r: 0.45, cutoff: 2600, env: 0.3, res: 0.15, detune: 7, vib: 5.2, vibDepth: 0.12, vibDelay: 0.3, gain: 0.32 },
    solo:    { osc: 'saw', a: 0.06, d: 0.2, s: 0.95, r: 0.25, cutoff: 3600, env: 0.4, res: 0.2, detune: 3, vib: 5.6, vibDepth: 0.22, vibDelay: 0.25, gain: 0.34 },
    brass:   { osc: 'saw', a: 0.05, d: 0.25, s: 0.85, r: 0.18, cutoff: 1400, env: 2.2, envA: 0.06, envD: 0.35, res: 0.1, detune: 4, vib: 5, vibDepth: 0.06, vibDelay: 0.4, gain: 0.34 },
    reed:    { osc: 'square', width: 0.32, a: 0.03, d: 0.1, s: 0.9, r: 0.12, cutoff: 2200, env: 0.6, res: 0.25, vib: 5.4, vibDepth: 0.08, vibDelay: 0.35, breath: 0.03, gain: 0.26 },
    flute:   { osc: 'tri', a: 0.06, d: 0.1, s: 0.9, r: 0.15, cutoff: 5000, env: 0.2, vib: 5.2, vibDepth: 0.1, vibDelay: 0.3, breath: 0.08, gain: 0.42 },
    pluck:   { osc: 'ks', a: 0.001, d: 0.1, s: 1, r: 0.3, cutoff: 8000, damp: 0.5, gain: 0.7 },
    harp:    { osc: 'ks', a: 0.001, d: 0.1, s: 1, r: 0.8, cutoff: 9000, damp: 0.25, gain: 0.7 },
    bass:    { osc: 'saw', a: 0.004, d: 0.35, s: 0.6, r: 0.1, cutoff: 900, env: 1.8, envD: 0.25, res: 0.2, sub: 0.5, gain: 0.45 },
    organ:   { osc: 'organ', a: 0.005, d: 0.05, s: 1, r: 0.06, cutoff: 9000, gain: 0.32 },
    pad:     { osc: 'saw', a: 0.6, d: 0.8, s: 0.8, r: 1.2, cutoff: 1800, env: 0.5, envA: 0.9, res: 0.15, detune: 11, vib: 0.3, vibDepth: 0.05, gain: 0.26 },
    bell:    { osc: 'bell', ratio: 3.5, index: 3, indexDecay: 1.2, a: 0.001, d: 2.8, s: 0, r: 1.2, cutoff: 14000, gain: 0.35 },
    mallet:  { osc: 'bell', ratio: 4, index: 1.2, indexDecay: 6, a: 0.001, d: 0.7, s: 0, r: 0.3, cutoff: 12000, gain: 0.5 },
    timpani: { osc: 'sine', a: 0.002, d: 1.4, s: 0, r: 0.6, cutoff: 3000, drop: 0.03, noise: 0.25, gain: 0.7 },
    lead:    { osc: 'square', width: 0.5, a: 0.005, d: 0.2, s: 0.8, r: 0.12, cutoff: 3000, env: 1.2, res: 0.3, vib: 5.5, vibDepth: 0.1, vibDelay: 0.4, gain: 0.25 },
    choir:   { osc: 'saw', a: 0.25, d: 0.3, s: 0.85, r: 0.5, cutoff: 1500, env: 0.2, res: 0.45, detune: 9, vib: 5, vibDepth: 0.1, vibDelay: 0.2, gain: 0.28 }
  };

  var PRESET_NAMES = {
    keys: 'Keys', piano: 'Piano', epiano: 'Electric Piano', strings: 'Strings', solo: 'Solo String', brass: 'Brass',
    reed: 'Reed', flute: 'Flute', pluck: 'Pluck', harp: 'Harp', bass: 'Bass', organ: 'Organ', pad: 'Pad',
    bell: 'Bell', mallet: 'Mallet', timpani: 'Timpani', lead: 'Lead', choir: 'Choir'
  };

  // ------------------------------------------------------------- voices --
  function Voice(sr) {
    this.sr = sr; this.on = false; this.pitch = 0; this.age = 0; this.released = false;
    this.ph1 = 0; this.ph2 = 0; this.ph3 = 0; this.mph = 0; this.lfo = 0;
    this.env = 0; this.stage = 0; this.fenv = 0; this.lp1 = 0; this.lp2 = 0;
    this.ks = null; this.ksi = 0; this.ksLast = 0; this.held = false;
  }

  function polyBlep(t, dt) {
    if (t < dt) { t /= dt; return t + t - t * t - 1; }
    if (t > 1 - dt) { t = (t - 1) / dt; return t * t + t + t + 1; }
    return 0;
  }

  function Synth(sr, presetName) {
    this.sr = sr;
    this.voices = [];
    for (var i = 0; i < 24; i++) this.voices.push(new Voice(sr));
    this.setPreset(presetName || 'keys');
    this.cc1 = 1; this.cc11 = 1; this.cc7 = 1; this.sustain = false; this.bend = 0;
    this.seed = 22222;
  }
  Synth.prototype.setPreset = function (name) {
    this.presetName = PRESETS[name] ? name : 'keys';
    this.p = PRESETS[this.presetName];
  };
  Synth.prototype.noise = function () {
    this.seed = (this.seed * 196314165 + 907633515) | 0;
    return this.seed / 2147483648;
  };
  Synth.prototype.noteOn = function (pitch, vel) {
    if (vel <= 0) return this.noteOff(pitch);
    var v = null, oldest = null;
    for (var i = 0; i < this.voices.length; i++) {
      var x = this.voices[i];
      if (!x.on) { v = x; break; }
      if (!oldest || x.age > oldest.age) oldest = x;
    }
    if (!v) v = oldest;
    var p = this.p;
    v.on = true; v.released = false; v.held = false; v.pitch = pitch; v.vel = vel / 127; v.age = 0;
    v.env = 0; v.stage = 0; v.fenv = 0; v.lp1 = v.lp1 * 0.2; v.lp2 = v.lp2 * 0.2;
    v.ph1 = Math.random(); v.ph2 = Math.random(); v.ph3 = 0; v.mph = 0;
    if (p.osc === 'ks') {
      var len = Math.max(2, Math.round(this.sr / mtof(pitch)));
      if (!v.ks || v.ks.length < len) v.ks = new Float32Array(Math.max(len, 2048));
      v.ksLen = len; v.ksi = 0; v.ksLast = 0;
      // A pluck: noise, darker when played softly.
      var c = 0.3 + 0.7 * v.vel, y = 0;
      for (var k = 0; k < len; k++) { y += c * (this.noise() - y); v.ks[k] = y; }
    }
  };
  Synth.prototype.noteOff = function (pitch) {
    for (var i = 0; i < this.voices.length; i++) {
      var v = this.voices[i];
      if (v.on && v.pitch === pitch && !v.released) {
        if (this.sustain) v.held = true; else { v.released = true; v.stage = 3; }
      }
    }
  };
  Synth.prototype.allOff = function () {
    for (var i = 0; i < this.voices.length; i++) { this.voices[i].on = false; }
  };
  Synth.prototype.cc = function (n, val) {
    var x = val / 127;
    if (n === 1) this.cc1 = 0.25 + 0.75 * x;
    else if (n === 11) this.cc11 = x;
    else if (n === 7) this.cc7 = x;
    else if (n === 64) {
      this.sustain = val >= 64;
      if (!this.sustain) for (var i = 0; i < this.voices.length; i++) {
        var v = this.voices[i];
        if (v.held) { v.held = false; v.released = true; v.stage = 3; }
      }
    } else if (n === 120 || n === 123) this.allOff();
  };
  Synth.prototype.pitchBend = function (v14) { this.bend = (v14 - 8192) / 8192 * 2; };

  Synth.prototype.render = function (n, L, R) {
    var p = this.p, sr = this.sr, dt = 1 / sr;
    var level = p.gain * this.cc11 * this.cc7;
    var bright = this.cc1;
    for (var vi = 0; vi < this.voices.length; vi++) {
      var v = this.voices[vi];
      if (!v.on) continue;
      var f0 = mtof(v.pitch + this.bend);
      var aRate = dt / Math.max(0.0005, p.a), dRate = dt / Math.max(0.001, p.d), rRate = dt / Math.max(0.005, p.r);
      var vel = v.vel;
      var baseCut = p.cutoff * (0.35 + 0.65 * vel) * bright * (1 + (v.pitch - 60) / 96);
      var pan = clamp((v.pitch - 64) / 90, -0.4, 0.4);
      var gl = Math.sqrt(0.5 * (1 - pan)), gr = Math.sqrt(0.5 * (1 + pan));
      for (var i = 0; i < n; i++) {
        // envelope
        if (v.stage === 0) { v.env += aRate; if (v.env >= 1) { v.env = 1; v.stage = 1; } }
        else if (v.stage === 1) { v.env -= (v.env - p.s) * dRate * 4; if (Math.abs(v.env - p.s) < 0.001) v.stage = 2; }
        else if (v.stage === 3) { v.env -= v.env * rRate * 5; if (v.env < 0.0005) { v.on = false; break; } }
        if (p.s === 0 && v.stage === 2) v.env -= v.env * dRate * 4;
        var t = v.age * dt;
        v.age++;
        var vib = 0;
        if (p.vib) {
          v.lfo += p.vib * dt;
          var depth = p.vibDepth * Math.min(1, Math.max(0, (t - (p.vibDelay || 0)) * 2));
          vib = Math.sin(2 * Math.PI * v.lfo) * depth;
        }
        var f = f0 * Math.pow(2, vib / 12);
        if (p.drop) f *= 1 + p.drop * Math.exp(-t * 30);
        var inc = f * dt, s = 0;
        switch (p.osc) {
          case 'saw': {
            var d2 = (p.detune || 0) / 1200;
            var inc2 = inc * Math.pow(2, d2);
            s = (2 * v.ph1 - 1) - polyBlep(v.ph1, inc);
            s += (2 * v.ph2 - 1) - polyBlep(v.ph2, inc2);
            s *= 0.5;
            v.ph1 += inc; if (v.ph1 >= 1) v.ph1 -= 1;
            v.ph2 += inc2; if (v.ph2 >= 1) v.ph2 -= 1;
            if (p.sub) { v.ph3 += inc * 0.5; if (v.ph3 >= 1) v.ph3 -= 1; s += p.sub * Math.sin(2 * Math.PI * v.ph3); }
            break;
          }
          case 'square': {
            var w = p.width || 0.5;
            s = (v.ph1 < w ? 1 : -1) + polyBlep(v.ph1, inc) - polyBlep((v.ph1 + 1 - w) % 1, inc);
            v.ph1 += inc; if (v.ph1 >= 1) v.ph1 -= 1;
            break;
          }
          case 'tri': {
            s = 1 - 4 * Math.abs(v.ph1 - 0.5);
            s = 0.7 * s + 0.3 * Math.sin(2 * Math.PI * v.ph1);
            v.ph1 += inc; if (v.ph1 >= 1) v.ph1 -= 1;
            break;
          }
          case 'sine': {
            s = Math.sin(2 * Math.PI * v.ph1);
            v.ph1 += inc; if (v.ph1 >= 1) v.ph1 -= 1;
            break;
          }
          case 'fm': case 'bell': {
            var idx = p.index * (0.4 + 0.6 * vel) * Math.exp(-t * p.indexDecay) * bright;
            var m = Math.sin(2 * Math.PI * v.mph);
            v.mph += inc * p.ratio; if (v.mph >= 1) v.mph -= 1;
            s = Math.sin(2 * Math.PI * v.ph1 + idx * m);
            if (p.detune) { s = 0.6 * s + 0.4 * Math.sin(2 * Math.PI * v.ph2 + idx * 0.5 * m); v.ph2 += inc * (1 + p.detune / 1200); if (v.ph2 >= 1) v.ph2 -= 1; }
            if (p.trem) s *= 1 - p.trem * (0.5 + 0.5 * Math.sin(2 * Math.PI * 5.5 * t));
            if (p.hammer && t < 0.01) s += p.hammer * this.noise() * (1 - t / 0.01);
            v.ph1 += inc; if (v.ph1 >= 1) v.ph1 -= 1;
            break;
          }
          case 'organ': {
            var ph = 2 * Math.PI * v.ph1;
            s = 0.5 * Math.sin(ph) + 0.35 * Math.sin(2 * ph) + 0.25 * Math.sin(3 * ph) + 0.15 * Math.sin(4 * ph) + 0.1 * Math.sin(6 * ph);
            v.ph1 += inc; if (v.ph1 >= 1) v.ph1 -= 1;
            break;
          }
          case 'ks': {
            var len = v.ksLen, k = v.ksi;
            var nxt = (k + 1) % len;
            var damp = 0.5 - (p.damp || 0.5) * 0.02;
            var out = v.ks[k];
            v.ks[k] = (v.ks[k] + v.ks[nxt]) * damp;
            v.ksi = nxt;
            s = out * 1.6;
            break;
          }
        }
        if (p.breath) s += p.breath * this.noise() * (0.5 + vel);
        if (p.noise) s += p.noise * this.noise() * Math.exp(-t * 40);
        // filter: two one-pole lowpasses, with an envelope on the cutoff
        var cut = baseCut;
        if (p.env) {
          var fe = p.envA ? Math.min(1, t / p.envA) * Math.exp(-Math.max(0, t - p.envA) / (p.envD || 0.4)) : Math.exp(-t / (p.envD || 0.4));
          cut *= 1 + p.env * fe * vel;
        }
        var g = 1 - Math.exp(-2 * Math.PI * clamp(cut, 40, sr * 0.45) * dt);
        v.lp1 += g * (s - v.lp1);
        v.lp2 += g * (v.lp1 - v.lp2);
        var y = (p.res ? v.lp2 + p.res * (v.lp1 - v.lp2) : v.lp2) * v.env * level * (0.35 + 0.65 * vel);
        L[i] += y * gl; R[i] += y * gr;
      }
    }
  };

  // ---------------------------------------------------------------- kit --
  function Kit(sr) { this.sr = sr; this.hits = []; this.seed = 1234567; this.cc7 = 1; this.cc11 = 1; }
  Kit.prototype.noise = Synth.prototype.noise;
  Kit.prototype.noteOn = function (pitch, vel) {
    if (vel <= 0) return;
    // a closed or pedal hat chokes an open one
    if (pitch === 42 || pitch === 44) this.hits.forEach(function (h) { if (h.pitch === 46) h.choke = true; });
    this.hits.push({ pitch: pitch, vel: vel / 127, t: 0, ph: 0, ph2: 0, bp1: 0, bp2: 0, hp: 0, lp: 0, choke: false });
    if (this.hits.length > 48) this.hits.shift();
  };
  Kit.prototype.noteOff = function () {};
  Kit.prototype.allOff = function () { this.hits = []; };
  Kit.prototype.cc = function (n, val) { if (n === 7) this.cc7 = val / 127; if (n === 11) this.cc11 = val / 127; if (n === 120 || n === 123) this.allOff(); };
  Kit.prototype.pitchBend = function () {};
  Kit.prototype.render = function (n, L, R) {
    var dt = 1 / this.sr, sr = this.sr, keep = [];
    var level = this.cc7 * this.cc11;
    for (var hi = 0; hi < this.hits.length; hi++) {
      var h = this.hits[hi], alive = true, pan = 0;
      for (var i = 0; i < n; i++) {
        var t = h.t, s = 0, env;
        switch (h.pitch) {
          case 35: case 36: {                                     // kick
            var f = 45 + 110 * Math.exp(-t * 28);
            h.ph += f * dt;
            env = Math.exp(-t * 7);
            s = Math.sin(2 * Math.PI * h.ph) * env * 1.1 + (t < 0.003 ? this.noise() * 0.4 : 0);
            if (t > 0.6) alive = false;
            break;
          }
          case 38: case 40: {                                     // snare
            h.ph += 185 * dt;
            var nz = this.noise();
            h.hp += 0.35 * (nz - h.hp);
            s = Math.sin(2 * Math.PI * h.ph) * Math.exp(-t * 22) * 0.6 + (nz - h.hp) * Math.exp(-t * 16) * 0.9;
            if (t > 0.35) alive = false;
            break;
          }
          case 37: {                                              // side stick
            h.ph += 1800 * dt;
            s = Math.sin(2 * Math.PI * h.ph) * Math.exp(-t * 90) * 0.7;
            if (t > 0.08) alive = false;
            break;
          }
          case 39: {                                              // clap
            var burst = (t % 0.011) < 0.004 && t < 0.035 ? 1 : 0;
            var nz2 = this.noise();
            h.bp1 += 0.3 * (nz2 - h.bp1); h.bp2 += 0.3 * (h.bp1 - h.bp2);
            s = (h.bp1 - h.bp2) * 2.2 * (burst + Math.exp(-Math.max(0, t - 0.035) * 14) * (t >= 0.035 ? 1 : 0));
            if (t > 0.4) alive = false;
            break;
          }
          case 42: case 44: case 46: {                            // hats
            var nz3 = this.noise();
            h.hp += 0.9 * (nz3 - h.hp);
            var decay = h.pitch === 46 ? 5 : (h.pitch === 44 ? 30 : 45);
            if (h.choke) decay = 80;
            s = (nz3 - h.hp) * Math.exp(-t * decay) * 0.5;
            pan = 0.25;
            if (t > (h.pitch === 46 ? 1.2 : 0.2) || (h.choke && t > 0.05)) alive = false;
            break;
          }
          case 41: case 43: case 45: case 47: case 48: case 50: {  // toms
            var base = { 41: 80, 43: 95, 45: 115, 47: 135, 48: 160, 50: 190 }[h.pitch];
            h.ph += base * (1 + 0.6 * Math.exp(-t * 18)) * dt;
            s = Math.sin(2 * Math.PI * h.ph) * Math.exp(-t * 7) * 0.9;
            pan = (h.pitch - 45) / 20;
            if (t > 0.7) alive = false;
            break;
          }
          case 49: case 57: case 52: case 55: {                   // crash, china, splash
            var nz4 = this.noise();
            h.hp += 0.75 * (nz4 - h.hp);
            s = (nz4 - h.hp) * Math.exp(-t * (h.pitch === 55 ? 6 : 1.6)) * 0.45;
            pan = h.pitch === 57 ? 0.4 : -0.3;
            if (t > 3) alive = false;
            break;
          }
          case 51: case 59: case 53: {                            // ride, bell
            var nz5 = this.noise();
            h.hp += 0.8 * (nz5 - h.hp);
            h.ph += 520 * dt; h.ph2 += 1370 * dt;
            var ping = (Math.sin(2 * Math.PI * h.ph) + Math.sin(2 * Math.PI * h.ph2)) * (h.pitch === 53 ? 0.35 : 0.12);
            s = ((nz5 - h.hp) * 0.22 + ping) * Math.exp(-t * (h.pitch === 53 ? 3 : 2.2));
            pan = 0.35;
            if (t > 2.5) alive = false;
            break;
          }
          case 54: case 69: case 70: case 82: {                   // tambourine, cabasa, maracas, shaker
            var nz6 = this.noise();
            h.hp += 0.85 * (nz6 - h.hp);
            s = (nz6 - h.hp) * Math.exp(-t * (h.pitch === 54 ? 9 : 25)) * 0.45;
            pan = -0.3;
            if (t > 0.5) alive = false;
            break;
          }
          case 56: {                                              // cowbell
            h.ph += 540 * dt; h.ph2 += 800 * dt;
            s = ((h.ph % 1 < 0.5 ? 1 : -1) + (h.ph2 % 1 < 0.5 ? 1 : -1)) * 0.18 * Math.exp(-t * 9);
            if (t > 0.5) alive = false;
            break;
          }
          case 75: case 76: case 77: {                            // claves, woodblocks
            h.ph += (h.pitch === 75 ? 2500 : h.pitch === 76 ? 1300 : 1000) * dt;
            s = Math.sin(2 * Math.PI * h.ph) * Math.exp(-t * 60) * 0.6;
            if (t > 0.15) alive = false;
            break;
          }
          default: {
            h.ph += (200 + (h.pitch - 60) * 12) * dt;
            s = Math.sin(2 * Math.PI * h.ph) * Math.exp(-t * 20) * 0.5;
            if (t > 0.3) alive = false;
          }
        }
        s *= h.vel * 0.8 * level;
        L[i] += s * (1 - Math.max(0, pan)); R[i] += s * (1 + Math.min(0, pan));
        h.t += dt;
        if (!alive) break;
      }
      if (alive) keep.push(h);
    }
    this.hits = keep;
  };

  // ------------------------------------------------- the Instant Instrument
  // A sound dropped on a track, played across the keyboard: its own pitch at
  // `root`, transposed by speed elsewhere, as a sampler does.
  function Sampler(sr) {
    this.sr = sr; this.voices = []; this.buffer = null; this.bufRate = sr; this.root = 60;
    this.a = 0.002; this.r = 0.25; this.cc7 = 1; this.cc11 = 1; this.sustain = false;
  }
  Sampler.prototype.load = function (channels, rate, root) {
    this.buffer = channels; this.bufRate = rate || this.sr; if (root !== undefined) this.root = root;
  };
  Sampler.prototype.noteOn = function (pitch, vel) {
    if (vel <= 0) return this.noteOff(pitch);
    if (!this.buffer) return;
    this.voices.push({ pitch: pitch, pos: 0, step: Math.pow(2, (pitch - this.root) / 12) * this.bufRate / this.sr, vel: vel / 127, env: 0, rel: false, held: false });
    if (this.voices.length > 32) this.voices.shift();
  };
  Sampler.prototype.noteOff = function (pitch) {
    var self = this;
    this.voices.forEach(function (v) { if (v.pitch === pitch && !v.rel) { if (self.sustain) v.held = true; else v.rel = true; } });
  };
  Sampler.prototype.allOff = function () { this.voices = []; };
  Sampler.prototype.cc = function (n, val) {
    if (n === 7) this.cc7 = val / 127; else if (n === 11) this.cc11 = val / 127;
    else if (n === 64) { this.sustain = val >= 64; if (!this.sustain) this.voices.forEach(function (v) { if (v.held) { v.held = false; v.rel = true; } }); }
    else if (n === 120 || n === 123) this.allOff();
  };
  Sampler.prototype.pitchBend = function () {};
  Sampler.prototype.render = function (n, L, R) {
    if (!this.buffer) return;
    var bl = this.buffer[0], br = this.buffer[1] || this.buffer[0], len = bl.length;
    var aR = 1 / (this.a * this.sr), rR = 1 / (this.r * this.sr), lev = this.cc7 * this.cc11 * 0.8;
    var keep = [];
    for (var vi = 0; vi < this.voices.length; vi++) {
      var v = this.voices[vi], alive = true;
      for (var i = 0; i < n; i++) {
        if (v.rel) { v.env -= rR; if (v.env <= 0) { alive = false; break; } }
        else if (v.env < 1) v.env = Math.min(1, v.env + aR);
        var p = v.pos, k = p | 0;
        if (k + 1 >= len) { alive = false; break; }
        var fr = p - k, g = v.env * v.vel * lev;
        L[i] += (bl[k] + (bl[k + 1] - bl[k]) * fr) * g;
        R[i] += (br[k] + (br[k + 1] - br[k]) * fr) * g;
        v.pos += v.step;
      }
      if (alive) keep.push(v);
    }
    this.voices = keep;
  };

  // -------------------------------------------------------------- click --
  function Click(sr) { this.sr = sr; this.hits = []; }
  Click.prototype.noteOn = function (pitch, vel) { this.hits.push({ f: pitch >= 76 ? 1760 : 1320, t: 0, v: vel / 127, ph: 0 }); };
  Click.prototype.noteOff = function () {};
  Click.prototype.allOff = function () { this.hits = []; };
  Click.prototype.cc = function () {};
  Click.prototype.pitchBend = function () {};
  Click.prototype.render = function (n, L, R) {
    var dt = 1 / this.sr, keep = [];
    this.hits.forEach(function (h) {
      for (var i = 0; i < n; i++) {
        h.ph += h.f * dt;
        var s = Math.sin(2 * Math.PI * h.ph) * Math.exp(-h.t * 70) * 0.35 * h.v;
        L[i] += s; R[i] += s; h.t += dt;
      }
      if (h.t < 0.1) keep.push(h);
    });
    this.hits = keep;
  };

  NS.Synth = Synth; NS.Kit = Kit; NS.Sampler = Sampler; NS.Click = Click;
  NS.PRESETS = PRESETS; NS.PRESET_NAMES = PRESET_NAMES; NS.mtof = mtof;
})(typeof module === 'object' && module.exports
  ? (module.exports = (globalThis.MiddawSynths = globalThis.MiddawSynths || {}))
  : (globalThis.MiddawSynths = globalThis.MiddawSynths || {}));
