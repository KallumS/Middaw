/* Sound: one audio-thread processor per track, a reverb return, the master.
 *
 * The page tells each track's processor its notes and its devices, and when
 * the transport started (as a frame of the audio clock); the processor plays
 * from there, so playback stays in time however busy the page gets. Mute and
 * solo are gains here; nothing about them reaches the notes.
 */
(function (MD) {
  'use strict';

  var ctx = null, ready = false, starting = null, master = null, returnNode = null, returnIn = null, clickNode = null;
  var nodes = {};                 // trackId -> { node, gain, pan, send, meter }
  var auditionNode = null, auditionTimer = null;
  var transport = { playing: false, startTime: 0, startBeat: 0, tempo: 120, loop: null, beatsPerBar: 4 };
  var metronome = false;
  var replies = {}, replyId = 1;
  var listeners = { meter: [], error: [], transport: [] };
  var lastSync = {};

  function on(kind, f) { listeners[kind].push(f); }
  function emit(kind, a, b) { listeners[kind].forEach(function (f) { f(a, b); }); }

  function init() {
    if (starting) return starting;
    var C = globalThis.AudioContext || globalThis.webkitAudioContext;
    ctx = new C({ latencyHint: 'interactive' });
    master = ctx.createGain();
    master.gain.value = 0.9;
    var comp = ctx.createDynamicsCompressor();
    comp.threshold.value = -6; comp.knee.value = 6; comp.ratio.value = 4; comp.attack.value = 0.003; comp.release.value = 0.15;
    master.connect(comp); comp.connect(ctx.destination);
    var base = MD.base || '';
    starting = ctx.audioWorklet.addModule(base + 'jsfx/jsfx.js')
      .then(function () { return ctx.audioWorklet.addModule(base + 'app/synths.js'); })
      .then(function () { return ctx.audioWorklet.addModule(base + 'app/worklet.js'); })
      .then(function () {
        returnIn = ctx.createGain();
        returnNode = makeNode('return');
        returnIn.connect(returnNode);
        returnNode.connect(master);
        clickNode = makeNode('click');
        clickNode.port.postMessage({ type: 'chain', inst: { id: 'click', kind: 'click' } });
        clickNode.connect(master);
        ready = true;
        return ctx;
      });
    return starting;
  }
  function resume() { if (ctx && ctx.state === 'suspended') return ctx.resume(); return Promise.resolve(); }

  function makeNode(id, c, options) {
    var node = new AudioWorkletNode(c || ctx, 'middaw-track', {
      numberOfInputs: 1, numberOfOutputs: 1, outputChannelCount: [2], processorOptions: options || {}
    });
    node.port.onmessage = function (e) {
      var m = e.data;
      if (m.type === 'meter') emit('meter', id, m);
      else if (m.type === 'reply' && replies[m.reply]) { replies[m.reply](m.value); delete replies[m.reply]; }
      else if (m.type === 'error') emit('error', id, m.message);
    };
    return node;
  }
  function ask(node, msg) {
    return new Promise(function (resolve) {
      var id = replyId++;
      replies[id] = resolve;
      msg.reply = id;
      node.port.postMessage(msg);
      setTimeout(function () { if (replies[id]) { delete replies[id]; resolve(null); } }, 3000);
    });
  }

  // ------------------------------------------------------------ events ---
  // A track's notes and controllers as MIDI events in beats. A note-off
  // sorts before a note-on at the same beat, so a repeated note retriggers.
  function trackEvents(track) {
    var ev = [];
    var ch = track.drums ? 9 : 0;
    track.clips.forEach(function (c) {
      c.notes.forEach(function (n) {
        if (n.start >= c.length - 1e-9) return;
        var s = c.start + n.start, e = c.start + Math.min(n.start + n.len, c.length);
        ev.push([s, 0x90 | ch, n.pitch, Math.max(1, Math.min(127, Math.round(n.vel)))]);
        ev.push([Math.max(s + 1 / 128, e - 1 / 256), 0x80 | ch, n.pitch, 0]);
      });
      Object.keys(c.cc || {}).forEach(function (num) {
        (c.cc[num] || []).forEach(function (pt) {
          if (pt[0] >= 0 && pt[0] <= c.length) ev.push([c.start + pt[0], 0xB0 | ch, Number(num), Math.max(0, Math.min(127, Math.round(pt[1])))]);
        });
      });
    });
    ev.sort(function (a, b) { return a[0] - b[0] || (a[1] & 0xF0) - (b[1] & 0xF0); });
    return ev;
  }

  function chainFor(track) {
    var D = MD.devices;
    var inst = track.sound ? D.spec(Object.assign({ id: 'inst-' + track.id }, track.sound)) : null;
    return {
      midiFx: (track.midiFx || []).map(D.spec).filter(Boolean),
      inst: inst,
      audioFx: (track.audioFx || []).map(D.spec).filter(Boolean)
    };
  }
  function chainKey(track) {
    return JSON.stringify([track.sound, track.midiFx.map(function (d) { return [d.id, d.device, d.preset]; }),
                           track.audioFx.map(function (d) { return [d.id, d.device]; })]);
  }

  // Bring the processors in line with the project.
  function sync(p) {
    if (!ready) return;
    var anySolo = p.tracks.some(function (t) { return t.solo; });
    var seen = {};
    p.tracks.forEach(function (t) {
      seen[t.id] = true;
      var n = nodes[t.id];
      if (!n) {
        var node = makeNode(t.id);
        var gain = ctx.createGain(), pan = ctx.createStereoPanner(), send = ctx.createGain();
        node.connect(gain); gain.connect(pan); pan.connect(master);
        pan.connect(send); send.connect(returnIn);
        n = nodes[t.id] = { node: node, gain: gain, pan: pan, send: send, events: null, chain: null };
        if (transport.playing) node.port.postMessage(transportMessage());
      }
      var audible = !t.mute && (!anySolo || t.solo);
      n.gain.gain.setTargetAtTime(audible ? volumeGain(t.volume) : 0, ctx.currentTime, 0.01);
      n.pan.pan.setTargetAtTime(t.pan || 0, ctx.currentTime, 0.01);
      n.send.gain.setTargetAtTime(t.send || 0, ctx.currentTime, 0.01);
      var ck = chainKey(t);
      if (n.chain !== ck) { n.chain = ck; n.node.port.postMessage(Object.assign({ type: 'chain' }, chainFor(t))); }
      var ev = trackEvents(t), ek = JSON.stringify(ev);
      if (n.events !== ek) { n.events = ek; n.node.port.postMessage({ type: 'events', events: ev }); }
    });
    Object.keys(nodes).forEach(function (id) {
      if (!seen[id]) { nodes[id].node.disconnect(); nodes[id].pan.disconnect(); delete nodes[id]; }
    });
    var rk = JSON.stringify(p.returns || []);
    if (lastSync.returns !== rk) {
      lastSync.returns = rk;
      returnNode.port.postMessage({ type: 'chain', inst: null,
        audioFx: (p.returns && p.returns[0] ? p.returns[0].audioFx : []).map(MD.devices.spec).filter(Boolean) });
    }
    transport.tempo = p.tempo;
    transport.beatsPerBar = MD.model.beatsPerBar(p);
    transport.loop = p.loop && p.loop.on ? { on: true, start: p.loop.start, end: p.loop.end } : null;
  }
  // While a fader moves: heard at once, the project untouched until it stops.
  function setMix(trackId, mix) {
    var n = nodes[trackId];
    if (!n) return;
    if (mix.volume !== undefined) n.gain.gain.setTargetAtTime(volumeGain(mix.volume), ctx.currentTime, 0.01);
    if (mix.pan !== undefined) n.pan.pan.setTargetAtTime(mix.pan, ctx.currentTime, 0.01);
    if (mix.send !== undefined) n.send.gain.setTargetAtTime(mix.send, ctx.currentTime, 0.01);
  }
  // The fader is in dB: 0.8 on the fader is unity.
  function volumeGain(v) { if (v <= 0) return 0; var db = (v - 0.8) * 60; return Math.pow(10, db / 20); }

  // ---------------------------------------------------------- transport --
  function transportMessage() {
    return { type: 'transport', playing: transport.playing,
             startFrame: Math.round(transport.startTime * ctx.sampleRate), startBeat: transport.startBeat,
             tempo: transport.tempo, loop: transport.loop, metronome: metronome, beatsPerBar: transport.beatsPerBar };
  }
  function broadcast() {
    var m = transportMessage();
    Object.keys(nodes).forEach(function (id) { nodes[id].node.port.postMessage(m); });
    if (clickNode) clickNode.port.postMessage(m);
    emit('transport', transport.playing);
  }
  function play(fromBeat) {
    return init().then(resume).then(function () {
      transport.playing = true;
      transport.startTime = ctx.currentTime + 0.06;
      transport.startBeat = Math.max(0, fromBeat || 0);
      broadcast();
    });
  }
  function stop() {
    if (!ctx) return;
    var at = position();
    transport.playing = false;
    transport.startBeat = at;
    broadcast();
    Object.keys(nodes).forEach(function (id) { nodes[id].node.port.postMessage({ type: 'panic' }); });
  }
  // Where the music is now, as heard: the output's own latency taken off.
  function position() {
    if (!ctx || !transport.playing) return transport.startBeat;
    var lat = (ctx.outputLatency || 0) + (ctx.baseLatency || 0);
    var t = Math.max(0, ctx.currentTime - lat - transport.startTime);
    var beat = transport.startBeat + t * transport.tempo / 60;
    var L = transport.loop;
    if (L && beat >= L.end && L.end > L.start) {
      if (transport.startBeat < L.end) {
        var len = L.end - L.start;
        beat = L.start + ((beat - L.end) % len);
      }
    }
    return beat;
  }
  function setMetronome(onOff) { metronome = onOff; if (transport.playing) broadcast(); }

  // -------------------------------------------------------------- live ---
  function live(trackId, data) {
    var n = nodes[trackId];
    if (n) n.node.port.postMessage({ type: 'live', data: data });
  }
  function slider(trackId, deviceId, num, value) {
    var n = trackId === 'return' ? { node: returnNode } : nodes[trackId];
    if (n) n.node.port.postMessage({ type: 'slider', id: deviceId, n: num, value: value });
  }
  function evalIn(trackId, deviceId, code) {
    var n = trackId === 'return' ? { node: returnNode } : nodes[trackId];
    return n ? ask(n.node, { type: 'eval', id: deviceId, code: code }) : Promise.resolve(null);
  }
  function vars(trackId, deviceId, names, extra) {
    var n = trackId === 'return' ? { node: returnNode } : nodes[trackId];
    if (!n) return Promise.resolve(null);
    var msg = { type: 'vars', id: deviceId, names: names };
    if (extra && extra.mem) msg.mem = extra.mem;
    if (extra && extra.strings) msg.strings = extra.strings;
    return ask(n.node, msg);
  }
  function gmem(trackId, name, writes) {
    var n = nodes[trackId];
    if (n) n.node.port.postMessage({ type: 'gmem', name: name, writes: writes });
  }
  // A sound for a device: the Instant Instrument plays it; a JSFX reads it
  // with file_open(name), and `then` is the EEL2 that loads it there.
  function sendSample(trackId, deviceId, buffer, root, name, then) {
    var n = nodes[trackId];
    if (!n) return;
    var chans = [];
    for (var c = 0; c < Math.min(2, buffer.numberOfChannels); c++) chans.push(new Float32Array(buffer.getChannelData(c)));
    var inter = new Float32Array(buffer.length * chans.length);
    for (var i = 0; i < buffer.length; i++) for (var k = 0; k < chans.length; k++) inter[i * chans.length + k] = chans[k][i];
    n.node.port.postMessage({ type: 'sample', id: deviceId, channels: chans, rate: buffer.sampleRate, root: root, interleaved: inter, name: name, then: then });
  }
  // Each device's state, as its @serialize writes it: kept in the project.
  function states() {
    var ids = Object.keys(nodes);
    return Promise.all(ids.map(function (id) { return ask(nodes[id].node, { type: 'serialize' }); }))
      .then(function (list) { var out = {}; ids.forEach(function (id, i) { out[id] = list[i] || {}; }); return out; });
  }

  // ---------------------------------------------------------- audition ---
  // A result heard as it is: every note on a piano, drums on the kit
  // (Miderator 0043), from the top, without touching the project.
  function audition(parts, opts) {
    opts = opts || {};
    return init().then(resume).then(function () {
      stopAudition();
      auditionNode = makeNode('audition');
      auditionNode.connect(master);
      var drums = parts.length && parts.every(function (p) { return p.drums; });
      auditionNode.port.postMessage({ type: 'chain', inst: drums ? { id: 'a', kind: 'kit' } : { id: 'a', kind: 'synth', preset: opts.preset || 'piano' } });
      var ev = [];
      parts.forEach(function (p) {
        (p.notes || []).forEach(function (n) {
          var s = (opts.offset || 0) + n.start;
          ev.push([s, 0x90, n.pitch, n.vel || 100]);
          ev.push([s + Math.max(0.05, n.len - 0.01), 0x80, n.pitch, 0]);
        });
      });
      ev.sort(function (a, b) { return a[0] - b[0] || (a[1] & 0xF0) - (b[1] & 0xF0); });
      auditionNode.port.postMessage({ type: 'events', events: ev });
      var tempo = opts.tempo || transport.tempo || 120;
      auditionNode.port.postMessage({ type: 'transport', playing: true, startFrame: Math.round((ctx.currentTime + 0.04) * ctx.sampleRate),
        startBeat: 0, tempo: tempo, loop: opts.loop ? { on: true, start: 0, end: opts.length } : null });
      var end = ev.length ? ev[ev.length - 1][0] : 0;
      if (!opts.loop) auditionTimer = setTimeout(stopAudition, (end * 60 / tempo + 1.5) * 1000);
      return { started: ctx.currentTime + 0.04, tempo: tempo };
    });
  }
  function stopAudition() {
    if (auditionTimer) { clearTimeout(auditionTimer); auditionTimer = null; }
    if (auditionNode) { auditionNode.port.postMessage({ type: 'panic' }); var a = auditionNode; setTimeout(function () { a.disconnect(); }, 300); auditionNode = null; }
  }
  function auditioning() { return !!auditionNode; }

  // ------------------------------------------------------------- render --
  // The song to a WAV, through the same processors, faster than real time.
  function renderWav(p, devStates) {
    var sr = 48000;
    var lengthBeats = Math.max(4, MD.model.endOfMusic(p));
    var seconds = lengthBeats * 60 / p.tempo + 3;
    var off = new OfflineAudioContext(2, Math.ceil(seconds * sr), sr);
    var base = MD.base || '';
    return off.audioWorklet.addModule(base + 'jsfx/jsfx.js')
      .then(function () { return off.audioWorklet.addModule(base + 'app/synths.js'); })
      .then(function () { return off.audioWorklet.addModule(base + 'app/worklet.js'); })
      .then(function () {
        var m = off.createGain(); m.gain.value = 0.9; m.connect(off.destination);
        var rin = off.createGain();
        var rnode = makeNode('render-return', off, { messages: [{ type: 'chain', inst: null,
          audioFx: (p.returns && p.returns[0] ? p.returns[0].audioFx : []).map(MD.devices.spec).filter(Boolean) }] });
        rin.connect(rnode); rnode.connect(m);
        var anySolo = p.tracks.some(function (t) { return t.solo; });
        p.tracks.forEach(function (t) {
          var chain = chainFor(t);
          var st = devStates && devStates[t.id];
          if (st) [].concat(chain.midiFx, chain.inst ? [chain.inst] : [], chain.audioFx).forEach(function (s) { if (s && st[s.id]) s.state = st[s.id]; });
          var node = makeNode('render-' + t.id, off, { messages: [
            Object.assign({ type: 'chain' }, chain),
            { type: 'events', events: trackEvents(t) },
            { type: 'transport', playing: true, startFrame: 0, startBeat: 0, tempo: p.tempo, loop: null }
          ] });
          var g = off.createGain(), pn = off.createStereoPanner(), sd = off.createGain();
          g.gain.value = (!t.mute && (!anySolo || t.solo)) ? volumeGain(t.volume) : 0;
          pn.pan.value = t.pan || 0; sd.gain.value = t.send || 0;
          node.connect(g); g.connect(pn); pn.connect(m); pn.connect(sd); sd.connect(rin);
        });
        return off.startRendering();
      })
      .then(function (buf) { return wavBlob(buf); });
  }
  function wavBlob(buf) {
    var n = buf.length, ch = buf.numberOfChannels, sr = buf.sampleRate;
    var data = new DataView(new ArrayBuffer(44 + n * ch * 2));
    function str(o, s) { for (var i = 0; i < s.length; i++) data.setUint8(o + i, s.charCodeAt(i)); }
    str(0, 'RIFF'); data.setUint32(4, 36 + n * ch * 2, true); str(8, 'WAVE'); str(12, 'fmt ');
    data.setUint32(16, 16, true); data.setUint16(20, 1, true); data.setUint16(22, ch, true);
    data.setUint32(24, sr, true); data.setUint32(28, sr * ch * 2, true); data.setUint16(32, ch * 2, true);
    data.setUint16(34, 16, true); str(36, 'data'); data.setUint32(40, n * ch * 2, true);
    var chans = []; for (var c = 0; c < ch; c++) chans.push(buf.getChannelData(c));
    var o = 44;
    for (var i = 0; i < n; i++) for (var k = 0; k < ch; k++) {
      var x = Math.max(-1, Math.min(1, chans[k][i]));
      data.setInt16(o, x < 0 ? x * 0x8000 : x * 0x7FFF, true); o += 2;
    }
    return new Blob([data.buffer], { type: 'audio/wav' });
  }

  function decode(arrayBuffer) { return init().then(function () { return ctx.decodeAudioData(arrayBuffer); }); }

  MD.audio = {
    init: init, resume: resume, sync: sync, setMix: setMix, play: play, stop: stop, position: position,
    isPlaying: function () { return transport.playing; }, setMetronome: setMetronome, metronome: function () { return metronome; },
    live: live, slider: slider, eval: evalIn, vars: vars, gmem: gmem, sendSample: sendSample, states: states,
    audition: audition, stopAudition: stopAudition, auditioning: auditioning,
    renderWav: renderWav, decode: decode, on: on, trackEvents: trackEvents,
    context: function () { return ready ? ctx : null; }, isReady: function () { return ready; }
  };
})(typeof module === 'object' && module.exports
  ? (module.exports = (globalThis.MD = globalThis.MD || {}))
  : (globalThis.MD = globalThis.MD || {}));
