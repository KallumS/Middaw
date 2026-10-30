/* One track in the audio thread: its notes, its transport, its devices.
 *
 * A track's whole chain runs here, in order, inside one processor - MIDI
 * effects (AutoCC, Midi Evolver, MIDI Production Center), then the
 * instrument (Middaw's own sounds, Instrument Creator, Transient Shuffler),
 * then audio effects (Reverberator) - so MIDI passes from one device to the
 * next at the sample it was sent, as it does on a REAPER track.
 *
 * The sequence is the track's notes in beats. Playback is worked out from the
 * frame the transport started on, so it stays in time however busy the page
 * is. Loaded into the AudioWorklet after web/jsfx/jsfx.js and app/synths.js.
 */
(function () {
  'use strict';
  var J = globalThis.MiddawJSFX, S = globalThis.MiddawSynths;
  var SR = typeof sampleRate !== 'undefined' ? sampleRate : 48000;

  function makeJSFX(spec) {
    var fx = new J.JSFX(spec.source, { sampleRate: SR, readImport: function (n) { return (spec.imports || {})[n]; } });
    if (spec.sliders) Object.keys(spec.sliders).forEach(function (k) { fx.setSliderByIndex(Number(k), spec.sliders[k]); });
    fx.init(SR);
    if (spec.state) fx.deserialize(spec.state);
    if (spec.after) { try { fx.eval(spec.after); } catch (e) { /* a device's own code */ } }
    return fx;
  }

  function Device(spec) {
    this.id = spec.id; this.kind = spec.kind; this.spec = spec;
    if (spec.kind === 'jsfx') this.fx = makeJSFX(spec);
    else if (spec.kind === 'synth') this.obj = new S.Synth(SR, spec.preset);
    else if (spec.kind === 'kit') this.obj = new S.Kit(SR);
    else if (spec.kind === 'sampler') { this.obj = new S.Sampler(SR); if (spec.sample) this.obj.load(spec.sample.channels, spec.sample.rate, spec.sample.root); }
    else if (spec.kind === 'click') this.obj = new S.Click(SR);
    this.key = JSON.stringify([spec.kind, spec.device, spec.preset, spec.sourceKey]);
  }
  Device.prototype.apply = function (obj, ev) {
    var d = ev.data, st = d[0] & 0xF0;
    if (st === 0x90) obj.noteOn(d[1], d[2]);
    else if (st === 0x80) obj.noteOff(d[1]);
    else if (st === 0xB0) obj.cc(d[1], d[2]);
    else if (st === 0xE0) obj.pitchBend(d[1] | (d[2] << 7));
  };
  // A built-in instrument rendered between its events, so each lands on its sample.
  Device.prototype.renderBuiltin = function (n, midi, L, R) {
    var obj = this.obj, pos = 0;
    for (var i = 0; i < midi.length; i++) {
      var ev = midi[i], at = Math.min(n, Math.max(0, ev.offset | 0));
      if (at > pos) { obj.render(at - pos, L.subarray(pos, at), R.subarray(pos, at)); pos = at; }
      this.apply(obj, ev);
    }
    if (pos < n) obj.render(n - pos, L.subarray(pos, n), R.subarray(pos, n));
  };

  var P = {};
  P.init = function () {
    this.events = [];           // [beat, b1, b2, b3], sorted by beat
    this.cursor = 0;
    this.playing = false; this.startFrame = 0; this.startBeat = 0; this.tempo = 120;
    this.loop = null; this.metronome = false; this.beatsPerBar = 4; this.isClick = false;
    this.midiFx = []; this.inst = null; this.audioFx = [];
    this.live = [];
    this.sounding = {};
    this.L = new Float32Array(128); this.R = new Float32Array(128);
    this.L2 = new Float32Array(128); this.R2 = new Float32Array(128);
    this.peakL = 0; this.peakR = 0; this.meterCount = 0;
    this.error = null;
    this.port.onmessage = this.onMessage.bind(this);
  }

  P.findDevice = function (id) {
    var all = this.midiFx.concat(this.inst ? [this.inst] : [], this.audioFx);
    for (var i = 0; i < all.length; i++) if (all[i].id === id) return all[i];
    return null;
  };

  P.onMessage = function (e) {
    var m = e.data, self = this;
    try {
      switch (m.type) {
        case 'events':
          this.events = m.events;
          this.seek(this.beatAt(currentFrame));
          break;
        case 'chain': {
          // Devices that are unchanged keep running, state and all.
          var old = {};
          this.midiFx.concat(this.inst ? [this.inst] : [], this.audioFx).forEach(function (d) { old[d.id] = d; });
          var reuse = function (spec) {
            var d = old[spec.id];
            var k = JSON.stringify([spec.kind, spec.device, spec.preset, spec.sourceKey]);
            if (d && d.key === k) {
              if (d.obj && spec.kind === 'synth' && spec.preset) d.obj.setPreset(spec.preset);
              if (spec.kind === 'sampler' && spec.sample && d.obj) d.obj.load(spec.sample.channels, spec.sample.rate, spec.sample.root);
              return d;
            }
            return new Device(spec);
          };
          this.midiFx = (m.midiFx || []).map(reuse);
          this.inst = m.inst ? reuse(m.inst) : null;
          this.audioFx = (m.audioFx || []).map(reuse);
          this.isClick = !!(m.inst && m.inst.kind === 'click');
          this.error = null;
          break;
        }
        case 'slider': {
          var d = this.findDevice(m.id);
          if (d && d.fx) d.fx.setSlider(m.n, m.value);
          break;
        }
        case 'eval': {
          var dv = this.findDevice(m.id), r = 0;
          if (dv && dv.fx) r = dv.fx.eval(m.code);
          if (m.reply) this.port.postMessage({ type: 'reply', reply: m.reply, value: r });
          break;
        }
        case 'vars': {
          var dd = this.findDevice(m.id), vals = {};
          if (dd && dd.fx) m.names.forEach(function (n) { vals[n] = dd.fx.getVar(n); });
          if (dd && dd.fx && m.mem) vals.__mem = m.mem.map(function (r) { var o = []; for (var i = 0; i < r[1]; i++) o.push(dd.fx.rd(r[0] + i)); return o; });
          if (dd && dd.fx && m.strings) vals.__str = m.strings.map(function (n) { return dd.fx.str(dd.fx.named(n)); });
          this.port.postMessage({ type: 'reply', reply: m.reply, value: vals });
          break;
        }
        case 'serialize': {
          var states = {};
          this.midiFx.concat(this.inst ? [this.inst] : [], this.audioFx).forEach(function (d) { if (d.fx) states[d.id] = d.fx.serialize(); });
          this.port.postMessage({ type: 'reply', reply: m.reply, value: states });
          break;
        }
        case 'sample': {
          var ds = this.findDevice(m.id);
          if (ds && ds.obj && ds.obj.load) ds.obj.load(m.channels, m.rate, m.root);
          if (ds && ds.fx) {
            var files = ds.fx.sampleFiles || (ds.fx.sampleFiles = {});
            files[m.name || 'sample'] = { samples: m.interleaved, channels: m.channels.length, rate: m.rate };
            ds.fx.openFile = function (name) { return files[name] || null; };
            if (m.then) ds.fx.eval(m.then);
          }
          break;
        }
        case 'transport':
          this.allNotesOff(0);
          this.playing = m.playing;
          this.startFrame = m.startFrame; this.startBeat = m.startBeat; this.tempo = m.tempo;
          this.loop = m.loop && m.loop.on ? m.loop : null;
          this.metronome = !!m.metronome; this.beatsPerBar = m.beatsPerBar || 4;
          this.seek(m.startBeat);
          break;
        case 'gmem': {
          // what a REAPER helper script would write into a plug-in's shared memory
          var G = J.sharedGmem || (J.sharedGmem = {});
          var g = G[m.name] || (G[m.name] = {});
          for (var w = 0; w < m.writes.length; w++) g[m.writes[w][0]] = m.writes[w][1];
          break;
        }
        case 'live':
          this.live.push({ offset: 0, data: m.data });
          break;
        case 'panic':
          this.allNotesOff(0);
          this.live.push({ offset: 0, data: [0xB0, 123, 0] });
          break;
      }
    } catch (err) {
      this.port.postMessage({ type: 'error', message: String(err && err.message || err) });
    }
  };

  P.beatAt = function (frame) {
    return this.startBeat + (frame - this.startFrame) / SR * this.tempo / 60;
  };
  P.frameOf = function (beat) {
    return this.startFrame + (beat - this.startBeat) * 60 / this.tempo * SR;
  };
  P.seek = function (beat) {
    var ev = this.events, lo = 0, hi = ev.length;
    while (lo < hi) { var mid = (lo + hi) >> 1; if (ev[mid][0] < beat - 1e-9) lo = mid + 1; else hi = mid; }
    this.cursor = lo;
  };
  P.allNotesOff = function (offset) {
    var out = this.pendingOff || (this.pendingOff = []);
    for (var k in this.sounding) {
      if (this.sounding[k] > 0) out.push({ offset: offset, data: [0x80, Number(k), 0] });
    }
    this.sounding = {};
  };
  // Events with beats in [b0, b1), as MIDI at their offsets in this block.
  P.collect = function (b0, b1, f0, out) {
    var ev = this.events;
    while (this.cursor < ev.length && ev[this.cursor][0] < b1 - 1e-9) {
      var e = ev[this.cursor++];
      if (e[0] < b0 - 1e-9) continue;
      var off = Math.round(this.frameOf(e[0]) - f0);
      if (off < 0) off = 0; if (off > 127) off = 127;
      var st = e[1] & 0xF0;
      if (st === 0x90 && e[3] > 0) this.sounding[e[2]] = (this.sounding[e[2]] || 0) + 1;
      else if (st === 0x80 || (st === 0x90 && e[3] === 0)) this.sounding[e[2]] = Math.max(0, (this.sounding[e[2]] || 0) - 1);
      out.push({ offset: off, data: [e[1], e[2], e[3]] });
    }
    if (this.metronome && this.isClick) {
      for (var b = Math.ceil(b0 - 1e-9); b < b1 - 1e-9; b++) {
        var o = Math.round(this.frameOf(b) - f0);
        var accent = Math.abs((b / this.beatsPerBar) - Math.round(b / this.beatsPerBar)) < 1e-6;
        out.push({ offset: Math.max(0, Math.min(127, o)), data: [0x99, accent ? 76 : 77, accent ? 120 : 90] });
      }
    }
  };

  P.process = function (inputs, outputs) {
    var out = outputs[0], n = out[0] ? out[0].length : 128;
    var f0 = currentFrame;
    var midi = this.pendingOff || [];
    this.pendingOff = null;
    if (this.live.length) { midi = midi.concat(this.live); this.live = []; }
    if (this.playing && f0 + n > this.startFrame) {
      var fs = Math.max(f0, this.startFrame);
      var b0 = this.beatAt(fs), b1 = this.beatAt(f0 + n);
      if (this.loop && b1 > this.loop.end && b0 < this.loop.end) {
        this.collect(b0, this.loop.end, f0, midi);
        var wrapAt = Math.round(this.frameOf(this.loop.end));
        this.allNotesOff(Math.max(0, Math.min(127, wrapAt - f0)));
        midi = midi.concat(this.pendingOff); this.pendingOff = null;
        this.startFrame = wrapAt; this.startBeat = this.loop.start;
        this.seek(this.loop.start);
        this.collect(this.loop.start, this.beatAt(f0 + n), f0, midi);
      } else {
        this.collect(b0, b1, f0, midi);
      }
    }
    midi.sort(function (a, b) { return a.offset - b.offset; });

    var L = this.L, R = this.R;
    L.fill(0); R.fill(0);
    if (this.error) { if (out[0]) out[0].fill(0); if (out[1]) out[1].fill(0); return true; }
    try {
      for (var i = 0; i < this.midiFx.length; i++) {
        var d = this.midiFx[i];
        if (d.fx) midi = d.fx.process(n, null, null, midi);
      }
      var inst = this.inst;
      var input = inputs && inputs[0];
      if (!inst && input && input[0]) {
        // no instrument: a return bus, its input is the sound to work on
        L.set(input[0]); R.set(input[1] || input[0]);
      }
      if (inst) {
        if (inst.obj) inst.renderBuiltin(n, midi, L, R);
        else if (inst.fx) inst.fx.process(n, [this.L2.fill(0), this.R2.fill(0)], [L, R], midi);
      }
      for (var k = 0; k < this.audioFx.length; k++) {
        var a = this.audioFx[k];
        if (!a.fx) continue;
        a.fx.process(n, [L, R], [this.L2, this.R2], []);
        var tl = L; L = this.L2; this.L2 = tl;
        var tr = R; R = this.R2; this.R2 = tr;
      }
      this.L = L; this.R = R;
    } catch (err) {
      this.error = String(err && err.message || err);
      this.port.postMessage({ type: 'error', message: this.error });
    }
    if (out[0]) out[0].set(L);
    if (out[1]) out[1].set(R);
    var pl = this.peakL, pr = this.peakR;
    for (var j = 0; j < n; j++) {
      var x = L[j] < 0 ? -L[j] : L[j], y = R[j] < 0 ? -R[j] : R[j];
      if (x > pl) pl = x; if (y > pr) pr = y;
    }
    this.peakL = pl; this.peakR = pr;
    if (++this.meterCount >= 6) {
      this.port.postMessage({ type: 'meter', l: pl, r: pr });
      this.peakL = 0; this.peakR = 0; this.meterCount = 0;
    }
    return true;
  };

  class TrackProcessor extends AudioWorkletProcessor {
    constructor(options) {
      super();
      this.init();
      // Offline rendering configures a processor up front: messages are not
      // guaranteed to arrive before an OfflineAudioContext starts.
      var o = options && options.processorOptions;
      if (o && o.messages) for (var i = 0; i < o.messages.length; i++) this.onMessage({ data: o.messages[i] });
    }
  }
  Object.keys(P).forEach(function (k) { TrackProcessor.prototype[k] = P[k]; });
  registerProcessor('middaw-track', TrackProcessor);
})();
