/* Middaw starts here: everything wired together.
 *
 * Actions (what a menu item, a key and a button all call), the transport,
 * the toolbar - with ScaleView's key display - the menus and keys, files in
 * and out, the MIDI keyboard, the Blocks toolbox, and boot.
 */
(function (MD) {
  'use strict';
  var app = MD.app, M = MD.model, U = MD.ui, D = MD.devices;
  var recording = null, held = {}, clipboard = null, blocksSession = null, blocksResults = [];

  // ============================================================ samples ===
  // Sounds dropped on a device are kept in the song, as 16-bit PCM.
  function b64FromBytes(u8) { var s = '', CH = 0x8000; for (var i = 0; i < u8.length; i += CH) s += String.fromCharCode.apply(null, u8.subarray(i, i + CH)); return btoa(s); }
  function bytesFromB64(b) { var s = atob(b), u8 = new Uint8Array(s.length); for (var i = 0; i < s.length; i++) u8[i] = s.charCodeAt(i); return u8; }
  MD.samples = {
    fromFile: function (file) {
      return file.arrayBuffer().then(MD.audio.decode).then(function (buf) {
        var max = Math.min(buf.length, buf.sampleRate * 16), ch = Math.min(2, buf.numberOfChannels);
        var pcm = new Int16Array(max * ch);
        for (var c = 0; c < ch; c++) { var d = buf.getChannelData(c); for (var i = 0; i < max; i++) pcm[i * ch + c] = Math.max(-32768, Math.min(32767, Math.round(d[i] * 32767))); }
        return { name: file.name, rate: buf.sampleRate, channels: ch, data: b64FromBytes(new Uint8Array(pcm.buffer)) };
      });
    },
    toBuffer: function (s) {
      var ctx = MD.audio.context();
      var pcm = new Int16Array(bytesFromB64(s.data).buffer), ch = s.channels || 1, n = Math.floor(pcm.length / ch);
      var buf = ctx.createBuffer(ch, n, s.rate);
      for (var c = 0; c < ch; c++) { var d = buf.getChannelData(c); for (var i = 0; i < n; i++) d[i] = pcm[i * ch + c] / 32768; }
      return buf;
    },
    send: function (trackId, devId, s, then, name) {
      if (!s || !MD.audio.context()) return;
      MD.audio.sendSample(trackId, devId, MD.samples.toBuffer(s), s.root || 60, name || s.name, then);
    },
    // A device's sounds, sent to it and loaded the way it loads them.
    load: function (trackId, dev) {
      if (dev.device === 'sampler' && dev.sample) MD.samples.send(trackId, dev.id, dev.sample);
      if (dev.device === 'shuffler' && dev.samples) {
        dev.samples.forEach(function (s, slot) {
          if (!s) return;
          var name = 'slot' + slot + '-' + s.name.replace(/"/g, '');
          MD.samples.send(trackId, dev.id, s, 'replace_slot(' + slot + ', "' + name + '"); recompute();', name);
        });
      }
    },
    loadAll: function (p) {
      p.tracks.forEach(function (t) { if (t.sound) MD.samples.load(t.id, t.sound); });
    }
  };

  // ============================================================ actions ===
  var A = MD.actions = {};
  A.undo = function () { var l = app.history.undo(); app.validate(); app.changed({ project: true }); U.status(l ? 'Undid ' + l + '.' : 'Nothing to undo.'); };
  A.redo = function () { var l = app.history.redo(); app.validate(); app.changed({ project: true }); U.status(l ? 'Redid ' + l + '.' : 'Nothing to redo.'); };
  A.recording = function () { return recording; };
  A.noteActivity = function (n) { MD.pass.event('notes', n || 1); };

  A.play = function (from) {
    var at = from === undefined ? app.caret : from;
    MD.audio.init().then(function () { MD.audio.sync(app.project()); return MD.audio.play(at); }).then(updateTransport);
  };
  A.stop = function () {
    MD.audio.stop();
    if (recording) finishRecording();
    updateTransport();
  };
  A.toggle = function (fromStart) {
    if (MD.audio.isPlaying()) A.stop();
    else A.play(fromStart ? 0 : app.caret);
  };
  A.toStart = function () { app.setCaret(0); app.view.scrollX = 0; app.view.rollScrollX = 0; if (MD.audio.isPlaying()) A.play(0); app.changed({ view: true }); };
  A.toEnd = function () { app.setCaret(M.endOfMusic(app.project())); };

  A.inspectorTab = function (tab) {
    app.view.itab = tab;
    document.querySelectorAll('#inspector [role=tab]').forEach(function (b) { b.setAttribute('aria-selected', String(b.dataset.itab === tab)); });
    document.getElementById('generate-open').setAttribute('aria-pressed', String(tab === 'generate'));
    if (tab === 'generate') MD.generate.render(); else MD.inspector.render();
  };

  // ------------------------------------------------------------- tracks ---
  function instrumentById(id) { return MD.engines.instruments().find(function (i) { return i.id === id; }); }
  A.makeTrack = function (q, instId, name) {
    var inst = instrumentById(instId) || { name: 'Piano', id: 'pno' };
    var drums = instId === 'kit' || !!inst.drums;
    var count = q.tracks.filter(function (t) { return t.instrument === instId; }).length;
    var t = M.newTrack({ name: name || (inst.name + (count ? ' ' + (count + 1) : '')), instrument: instId, drums: drums,
      sound: drums ? D.make('kit') : D.make('synth', { preset: D.PRESET_FOR[instId] || 'keys' }) });
    return t;
  };
  A.trackForRole = function (q, role, name) {
    var map = { melody: 'pno', counter: 'vla', chords: 'pno', bass: 'ubass', drums: 'kit' };
    var t = A.makeTrack(q, map[role] || 'pno', name);
    if (role === 'chords') t.sound.preset = 'epiano';
    if (role === 'melody') t.sound.preset = 'piano';
    t.role = role;
    return t;
  };
  A.addInstrument = function (instId) {
    var id = null;
    app.commit('Add Track', function (q) { var t = A.makeTrack(q, instId); q.tracks.push(t); id = t.id; });
    app.selectTrack(id);
    MD.pass.event('track', 1);
  };
  A.addEnsemble = function (e) {
    var ids = [];
    app.commit('Add ' + e.name, function (q) {
      e.ids.forEach(function (i) { var t = A.makeTrack(q, i); q.tracks.push(t); ids.push(t.id); });
      if (!q.title || q.title === 'Untitled') q.title = e.name;
    });
    if (ids[0]) app.selectTrack(ids[0]);
    MD.pass.event('track', ids.length);
    U.status('Added ' + e.name + ': ' + ids.length + (ids.length === 1 ? ' track.' : ' tracks.'), { undo: A.undo });
  };
  A.setInstrument = function (trackId, instId) {
    app.commit('Change Instrument', function (q) {
      var t = M.track(q, trackId), inst = instrumentById(instId);
      var oldName = (instrumentById(t.instrument) || {}).name;
      t.instrument = instId;
      t.drums = instId === 'kit';
      if (t.drums && t.sound.device !== 'kit') t.sound = D.make('kit');
      if (!t.drums && t.sound.device === 'kit') t.sound = D.make('synth', { preset: D.PRESET_FOR[instId] || 'keys' });
      if (t.sound.device === 'synth') t.sound.preset = D.PRESET_FOR[instId] || t.sound.preset;
      if (inst && (!t.name || t.name === oldName || /^Track/.test(t.name))) t.name = inst.name;
    });
  };
  A.addDevice = function (trackId, device) {
    var d = D.DEVICES[device];
    app.commit('Add ' + d.name, function (q) {
      var t = M.track(q, trackId);
      var dev = D.make(device);
      if (device === 'autocc') {
        var fam = (instrumentById(t.instrument) || {}).family;
        dev.sliders[1] = fam === 'Strings' ? 1 : fam === 'Brass' ? 2 : fam === 'Woodwind' ? 3 : 0;
      }
      if (device === 'reverberator') dev.sliders[2] = 30;
      if (d.type === 'instrument') {
        t.sound = dev;
        if (device === 'creator') { var pr = D.DEVICES.creator.presets[1]; dev.presetIndex = 1; dev.presetName = pr.name; pr.values.forEach(function (v, j) { dev.sliders[j + 1] = v; }); }
        t.drums = device === 'kit';
      } else if (d.type === 'midi') t.midiFx.push(dev);
      else t.audioFx.push(dev);
    });
    MD.pass.event('fx', 1, { name: d.name });
    A.inspectorTab('track');
  };
  A.deleteTrack = function (id) {
    var t = M.track(app.project(), id);
    app.commit('Delete Track', function (q) { q.tracks = q.tracks.filter(function (x) { return x.id !== id; }); });
    U.status('Deleted ' + (t ? t.name : 'the track') + '.', { undo: A.undo });
  };
  A.duplicateTrack = function (id) {
    var nid = null;
    app.commit('Duplicate Track', function (q) {
      var i = q.tracks.findIndex(function (x) { return x.id === id; });
      var c = M.clone(q.tracks[i]); c.id = M.uid('t'); c.name += ' copy';
      c.clips.forEach(function (cl) { cl.id = M.uid('c'); });
      [c.sound].concat(c.midiFx, c.audioFx).forEach(function (d) { if (d) d.id = M.uid('d'); });
      q.tracks.splice(i + 1, 0, c); nid = c.id;
    });
    app.selectTrack(nid);
  };

  // -------------------------------------------------------------- clips ---
  function chosenNotesOr(fn) {
    var c = app.clip();
    if (!c) return false;
    return { clip: c, indices: app.sel.notes.length ? app.sel.notes.slice() : c.notes.map(function (_, i) { return i; }) };
  }
  A.deleteSelection = function () {
    var c = app.clip();
    if (c && app.sel.notes.length) {
      var del = app.sel.notes.slice();
      app.commit('Delete Notes', function (q) { var cl = M.clipById(q, c.id).clip; cl.notes = cl.notes.filter(function (_, i) { return del.indexOf(i) < 0; }); });
      app.sel.notes = [];
    } else if (c) {
      app.commit('Delete Clip', function (q) { var f = M.clipById(q, c.id); f.track.clips = f.track.clips.filter(function (x) { return x.id !== c.id; }); });
    } else if (app.sel.range) {
      var r = app.sel.range;
      app.commit('Clear the Chosen Bars', function (q) { r.trackIds.forEach(function (id) { M.clearSpan(M.track(q, id), r.start, r.end); }); });
    }
  };
  A.duplicate = function () {
    var c = app.clip(), t = app.track();
    if (!c) return;
    var nid = null;
    app.commit('Duplicate Clip', function (q) { var f = M.clipById(q, c.id); nid = M.duplicateClip(f.track, f.clip).id; });
    app.selectClip(t.id, nid);
  };
  A.split = function () {
    var c = app.clip();
    if (!c) return;
    app.commit('Split Clip', function (q) { var f = M.clipById(q, c.id); M.splitClip(f.track, f.clip, app.caret); });
  };
  A.copy = function () {
    var c = app.clip();
    if (!c) return;
    if (app.sel.notes.length) clipboard = { notes: app.sel.notes.map(function (i) { return M.clone(c.notes[i]); }) };
    else clipboard = { clip: M.clone(c) };
    U.status(app.sel.notes.length ? 'Copied ' + app.sel.notes.length + ' notes.' : 'Copied the clip.');
  };
  A.canPaste = function () { return !!clipboard; };
  A.paste = function () {
    var t = app.track(), p = app.project();
    if (!clipboard || !t) return;
    if (clipboard.clip) {
      var nid = null;
      app.commit('Paste Clip', function (q) {
        var c = M.clone(clipboard.clip); c.id = M.uid('c'); c.start = M.snap(q, app.caret, M.beatsPerBar(q), 'floor');
        var tt = M.track(q, t.id); M.clearSpan(tt, c.start, c.start + c.length); tt.clips.push(c); tt.clips.sort(function (a, b) { return a.start - b.start; }); nid = c.id;
      });
      app.selectClip(t.id, nid);
    } else {
      var c = app.clip() || M.clipAt(t, app.caret);
      if (!c) return;
      var first = Math.min.apply(null, clipboard.notes.map(function (n) { return n.start; }));
      var base = app.caret - c.start, n0 = c.notes.length;
      app.commit('Paste Notes', function (q) {
        var cl = M.clipById(q, c.id).clip;
        clipboard.notes.forEach(function (n) { var x = M.clone(n); x.start = base + n.start - first; if (x.start >= 0 && x.start < cl.length) cl.notes.push(x); });
      });
      app.selectClip(t.id, c.id);
      app.sel.notes = clipboard.notes.map(function (_, i) { return n0 + i; });
    }
  };
  A.selectAll = function () { var c = app.clip(); if (c) { app.sel.notes = c.notes.map(function (_, i) { return i; }); app.changed({ selection: true }); } };
  A.quantize = function () {
    var s = chosenNotesOr();
    if (!s) return;
    var grid = app.grid();
    app.commit('Quantize', function (q) {
      var f = M.clipById(q, s.clip.id);
      var notes = s.indices.map(function (i) { return f.clip.notes[i]; });
      notes.forEach(function (n) { n.start += f.clip.start; });
      M.quantize(q, notes, grid, 1);
      notes.forEach(function (n) { n.start -= f.clip.start; });
    });
  };
  A.transpose = function (by) {
    var s = chosenNotesOr();
    if (!s) return;
    app.commit(by > 0 ? 'Transpose Up' : 'Transpose Down', function (q) {
      var cl = M.clipById(q, s.clip.id).clip;
      M.transpose(s.indices.map(function (i) { return cl.notes[i]; }), by);
    });
  };
  A.nudge = function (by) {
    var s = chosenNotesOr();
    if (!s || !app.sel.notes.length) return;
    app.commit('Move Notes', function (q) {
      var cl = M.clipById(q, s.clip.id).clip;
      s.indices.forEach(function (i) { cl.notes[i].start = Math.max(0, cl.notes[i].start + by); });
    });
  };
  // Midi Catalogue's Shape It, on any clip: the harmony kept, the contour turned.
  A.transform = function (kind) {
    var c = app.clip(), t = app.track();
    if (!c) return;
    // On a kit a note number names a drum: mirroring or keying it swaps instruments.
    if (t && t.drums && (kind === 'invert' || kind === 'key')) { U.status('Drums have no key, so they are not turned or fitted to one.'); return; }
    var labels = { invert: 'Turn Upside Down', retrograde: 'Play Backwards', half: 'Half Speed', double: 'Double Speed', key: 'Fit to the Key' };
    app.commit(labels[kind], function (q) {
      var cl = M.clipById(q, c.id).clip;
      if (kind === 'invert') M.invert(cl.notes, q.key);
      else if (kind === 'retrograde') M.retrograde(cl.notes, cl.length);
      else if (kind === 'half') { M.scaleTime(cl.notes, 2); cl.length *= 2; }
      else if (kind === 'double') { M.scaleTime(cl.notes, 0.5); cl.length = Math.max(M.beatsPerBar(q), cl.length / 2); }
      else if (kind === 'key') M.fitToKey(cl.notes, q.key);
    });
  };
  A.transformMenu = function (anchor, pos) {
    var drums = !!(app.track() && app.track().drums);
    U.menu(anchor, [
      { label: 'Turn Upside Down', disabled: drums, action: function () { A.transform('invert'); } },
      { label: 'Play Backwards', action: function () { A.transform('retrograde'); } },
      { label: 'Half Speed', action: function () { A.transform('half'); } },
      { label: 'Double Speed', action: function () { A.transform('double'); } },
      { label: 'Fit to the Key', disabled: drums, action: function () { A.transform('key'); } }
    ], pos);
  };
  A.clipMenu = function (x, y) {
    var c = app.clip();
    if (!c) return;
    U.menu(null, [
      { label: 'Vary…', action: function () { MD.generate.open('midi-variator'); } },
      { label: 'Suggest…', action: function () { MD.generate.open('midi-suggester'); } },
      { label: 'Transform', action: function () { A.transformMenu(null, { x: x, y: y }); } },
      { label: 'Draw Dynamics with AutoCC', action: A.seedCC },
      { separator: true },
      { label: 'Copy', keys: '⌘C', action: A.copy },
      { label: 'Duplicate', keys: '⌘D', action: A.duplicate },
      { label: 'Split at the Caret', keys: '⌘E', action: A.split },
      { label: 'Quantize', keys: 'Q', action: A.quantize },
      { label: 'Export as MIDI…', action: function () { A.exportMidi(true); } },
      { separator: true },
      { label: 'Delete', keys: '⌫', action: A.deleteSelection }
    ], { x: x, y: y });
  };

  // AutoCC, run over the clip: the curves it would play, written into the
  // clip's controller lanes (Miderator's "CC lanes seeded by AutoCC").
  A.seedCC = function () {
    var c = app.clip(), t = app.track(), p = app.project();
    if (!c || !t) { U.status('Choose a clip first.'); return; }
    var J = globalThis.MiddawJSFX, dev = t.midiFx.find(function (d) { return d.device === 'autocc'; });
    var fx = new J.JSFX(D.source('AutoCC.jsfx'), {});
    var fam = (instrumentById(t.instrument) || {}).family;
    if (dev) Object.keys(dev.sliders).forEach(function (k) { fx.setSliderByIndex(Number(k), dev.sliders[k]); });
    else fx.setSliderByIndex(1, fam === 'Strings' ? 1 : fam === 'Brass' ? 2 : fam === 'Woodwind' ? 3 : 0);
    var sr = 48000, bs = 256;
    fx.init(sr);
    fx.setTime({ tempo: p.tempo, playState: 1, num: p.meter[0], den: p.meter[1] });
    var ev = [];
    c.notes.forEach(function (n) {
      ev.push([n.start, [0x90, n.pitch, n.vel]]);
      ev.push([n.start + n.len, [0x80, n.pitch, 0]]);
    });
    ev.sort(function (a, b) { return a[0] - b[0]; });
    var spb = sr * 60 / p.tempo, total = Math.ceil(c.length * spb / bs) + 8, k = 0, lanes = {};
    for (var b = 0; b < total; b++) {
      var midi = [];
      while (k < ev.length && ev[k][0] * spb < (b + 1) * bs) { midi.push({ offset: Math.max(0, Math.round(ev[k][0] * spb - b * bs)), data: ev[k][1] }); k++; }
      fx.setTime({ beat: b * bs / spb, seconds: b * bs / sr });
      fx.process(bs, null, null, midi).forEach(function (m) {
        if ((m.data[0] & 0xF0) !== 0xB0) return;
        var beat = (b * bs + m.offset) / spb;
        if (beat > c.length) return;
        (lanes[m.data[1]] = lanes[m.data[1]] || []).push([Math.round(beat * 1000) / 1000, m.data[2]]);
      });
    }
    // keep a point where the value turns, not every step
    Object.keys(lanes).forEach(function (n) {
      var pts = lanes[n], out = [];
      pts.forEach(function (pt, i) {
        var prev = out[out.length - 1];
        if (!prev || i === pts.length - 1 || Math.abs(pt[1] - prev[1]) >= 2) out.push(pt);
      });
      lanes[n] = out;
    });
    var names = Object.keys(lanes);
    if (!names.length) { U.status('AutoCC drew nothing for this clip.'); return; }
    app.commit('Draw Dynamics with AutoCC', function (q) { var cl = M.clipById(q, c.id).clip; cl.cc = cl.cc || {}; names.forEach(function (n) { cl.cc[n] = lanes[n]; }); });
    app.view.lane = '1'; document.getElementById('lane').value = '1';
    U.status('AutoCC drew CC' + names.join(', CC') + ' into the clip.', { undo: A.undo });
  };

  // What Midi Evolver last played (its take), put into the track at the caret.
  A.evolverTake = function (dev) {
    var t = app.track();
    MD.audio.vars(t.id, dev.id, ['rec_n', 'take_len', 'rec_base']).then(function (v) {
      if (!v || !v.rec_n) { U.status('Hold a chord first: Midi Evolver keeps what it plays as the take.'); return; }
      return MD.audio.vars(t.id, dev.id, [], { mem: [[v.rec_base, v.rec_n * 4]] }).then(function (w) {
        var mem = w.__mem[0], on = {}, notes = [];
        for (var i = 0; i < v.rec_n; i++) {
          var at = mem[i * 4], st = mem[i * 4 + 1] & 0xF0, pitch = mem[i * 4 + 2], vel = mem[i * 4 + 3];
          if (st === 0x90 && vel > 0) on[pitch] = { start: at, pitch: pitch, vel: vel };
          else if ((st === 0x80 || st === 0x90) && on[pitch]) { var n = on[pitch]; n.len = Math.max(1 / 32, at - n.start); notes.push(n); delete on[pitch]; }
        }
        Object.keys(on).forEach(function (k) { var n = on[k]; n.len = Math.max(1 / 32, v.take_len - n.start); notes.push(n); });
        var p = app.project(), bpb = M.beatsPerBar(p), at0 = Math.floor(app.caret / bpb) * bpb;
        var len = Math.ceil(Math.max(v.take_len, 1) / bpb) * bpb, id = null;
        app.commit('Insert the Take', function (q) { id = M.placeNotes(q, t.id, at0, len, notes, { name: 'Midi Evolver take', source: { generator: 'Midi Evolver' } }).id; });
        app.selectClip(t.id, id);
        U.status('Inserted the take: ' + notes.length + ' notes. Take Midi Evolver off the track to hear just the notes.', { undo: A.undo });
        MD.pass.event('take', 1);
      });
    });
  };

  // The chosen clip into MIDI Production Center, as its REAPER loader writes it.
  A.mpcLoad = function (dev) {
    var t = app.track(), c = app.clip(), p = app.project();
    if (!c) return;
    MD.audio.vars(t.id, dev.id, ['slider48']).then(function (v) {
      var id = v && v.slider48;
      if (!id) { U.status('MIDI Production Center is still starting. Try again in a moment.'); return; }
      var w = [], notes = c.notes.slice(0, 8192);
      notes.forEach(function (n, i) { var b = 100 + i * 5; w.push([b, n.start], [b + 1, n.len], [b + 2, n.pitch], [b + 3, n.vel], [b + 4, 0]); });
      var name = (c.name || 'Clip').replace(/[^\x20-\x7e]/g, '').slice(0, 64);
      for (var k = 0; k < name.length; k++) w.push([61000 + k, name.charCodeAt(k)]);
      w.push([1, id], [2, notes.length], [3, c.length], [4, p.tempo], [5, p.meter[0]], [6, p.meter[1]], [7, 0], [8, name.length]);
      w.push([0, Date.now() % 1000000 + 1]);
      MD.audio.gmem(t.id, 'MIDIProductionCenter', w);
      U.status('Loaded “' + name + '” into MIDI Production Center and chopped it onto the pads.');
    });
  };

  // A block of notes (Starting Blocks, a Battle Pass idea) at the caret.
  A.insertBlock = function (block, name) {
    var t = app.track(), p = app.project();
    if (!t) { U.status('Choose a track first.'); return; }
    var notes = (Array.isArray(block.notes) ? block.notes : Object.values(block.notes || {})).map(M.asNote);
    var beats = block.beats || notes.reduce(function (m, n) { return Math.max(m, n.start + n.len); }, 0);
    var at = app.caret, bpb = M.beatsPerBar(p), id = null;
    // Into the clip under the caret, or the one that ends at it, which grows
    // to take the block: blocks laid one after another are one phrase.
    var into = M.clipAt(t, at) || t.clips.filter(function (c) { return Math.abs(c.start + c.length - at) < 1e-6; })[0];
    app.commit('Insert ' + (name || block.name || 'Block'), function (q) {
      var tt = M.track(q, t.id);
      if (into) {
        var cl = M.clipById(q, into.id).clip, end = cl.start + cl.length;
        var need = Math.ceil((at + beats - cl.start) / bpb - 1e-9) * bpb;
        if (cl.start + need > end + 1e-9) {
          M.clearSpan(tt, end, cl.start + need);
          cl = M.clipById(q, into.id).clip;
          cl.length = need;
        }
        notes.forEach(function (n) { cl.notes.push({ start: at - cl.start + n.start, len: n.len, pitch: n.pitch, vel: n.vel }); });
        cl.notes.sort(function (a, b) { return a.start - b.start || a.pitch - b.pitch; });
        id = cl.id;
      } else {
        id = M.placeNotes(q, tt.id, at, Math.max(beats, 0.25), notes, { name: block.name || name, source: { generator: 'Starting Blocks', title: block.name } }).id;
      }
    });
    app.selectClip(t.id, id);
    app.setCaret(at + beats);
    MD.pass.event('notes', notes.length);
  };

  // ScaleView's key from Middaw's Python spec.
  A.keyFromSpec = function (spec) {
    var modes = { major: 1, minor: 2, aeolian: 9, harmonic_minor: 3, melodic_minor: 2, ionian: 4, dorian: 5, phrygian: 6, lydian: 7,
                  mixolydian: 8, locrian: 9, major_pentatonic: 10, minor_pentatonic: 11, major_blues: 12, blues: 13, whole_tone: 14,
                  diminished_wh: 15, diminished_hw: 16 };
    var name = String(spec.key || '').split(' ')[0];
    var root = M.ROOT_NAMES.indexOf(name) + 1;
    if (root <= 0) root = M.ROOT_PC.indexOf(spec.tonic % 12) + 1;
    return { root: root, scale: modes[spec.mode] || 1 };
  };
  A.replaceWithComposed = function () {
    app.commit('Replace the Song', function (q) { q.tracks = []; });
    MD.generate.insertComposed(true);
  };

  // ------------------------------------------------------------- files ----
  function download(blob, name) {
    var a = U.el('a', { href: URL.createObjectURL(blob), download: name });
    document.body.appendChild(a); a.click(); a.remove();
    setTimeout(function () { URL.revokeObjectURL(a.href); }, 5000);
  }
  function fileName(ext) { return (app.project().title || 'Untitled').replace(/[^\w\- ]+/g, '').trim().replace(/\s+/g, ' ') + ext; }
  // Devices' own state (Evolver's take, MPC's phrase) goes in with the song.
  function withStates() {
    var ctx = MD.audio.context();
    if (!ctx) return Promise.resolve(app.project());
    return MD.audio.states().then(function (st) {
      var p = M.clone(app.project());
      p.tracks.forEach(function (t) {
        var s = st[t.id] || {};
        [t.sound].concat(t.midiFx, t.audioFx).forEach(function (d) { if (d && s[d.id]) d.state = s[d.id]; });
      });
      return p;
    });
  }
  A.save = function () {
    withStates().then(function (p) {
      download(new Blob([JSON.stringify(p)], { type: 'application/json' }), fileName('.middaw'));
      U.status('Saved ' + fileName('.middaw') + ' to your downloads.');
    });
  };
  A.newSong = function () {
    U.sheet('New Song', function (b, close) {
      var cards = U.el('div', { class: 'cards' });
      [{ name: 'Empty', ids: [] }].concat(MD.browser.ENSEMBLES).forEach(function (e) {
        cards.appendChild(U.el('button', { type: 'button', class: 'card', onclick: function () {
          close();
          app.history.replace(M.newProject({ title: e.ids.length ? e.name : 'Untitled' }), 'New Song');
          setupReturn();
          app.sel = { trackId: null, clipId: null, notes: [], range: null }; app.caret = 0;
          if (e.ids.length) A.addEnsemble(e); else app.changed({ all: true });
        } }, [U.el('strong', { text: e.name }), U.el('span', { class: 'd', text: e.ids.length ? e.ids.length + (e.ids.length === 1 ? ' instrument' : ' instruments') : 'No tracks' })]));
      });
      b.appendChild(cards);
      b.appendChild(U.el('div', { class: 'actions' }, [U.button('Cancel', close)]));
    });
  };
  A.open = function () {
    var inp = document.getElementById('file-open');
    inp.value = '';
    inp.onchange = function () { if (inp.files[0]) openFile(inp.files[0]); };
    inp.click();
  };
  function openFile(file) {
    if (/\.midi?$/i.test(file.name)) return importMidi(file);
    file.text().then(function (txt) {
      var p = JSON.parse(txt);
      if (!p.tracks) throw new Error('not a Middaw song');
      app.history.replace(p, 'Open');
      app.sel = { trackId: p.tracks[0] ? p.tracks[0].id : null, clipId: null, notes: [], range: null };
      app.caret = 0;
      app.changed({ all: true });
      MD.samples.loadAll(p);
      U.status('Opened ' + file.name + '.');
    }).catch(function (e) { U.status('That file could not be opened: ' + e.message, { warning: true }); });
  }
  function importMidi(file) {
    file.arrayBuffer().then(function (buf) {
      return fetch('/api/midi/read', { method: 'POST', body: buf }).then(function (r) { return r.json().then(function (d) { if (!r.ok) throw new Error(d.error); return d; }); });
    }).then(function (d) {
      var ids = [];
      app.commit('Import ' + file.name, function (q) {
        if (!q.tracks.length) { q.tempo = Math.round(d.tempo); q.meter = d.meter; if (d.key) q.key = A.keyFromSpec({ key: d.key.label, mode: d.key.mode, tonic: d.key.tonic }); }
        d.tracks.forEach(function (tr) {
          if (!tr.notes.length) return;
          var t = A.makeTrack(q, tr.drums ? 'kit' : 'pno', tr.name || 'Imported');
          q.tracks.push(t);
          var end = tr.notes.reduce(function (m, n) { return Math.max(m, n.start + n.duration); }, 0);
          var bpb = M.beatsPerBar(q);
          var clip = M.placeNotes(q, t.id, 0, Math.max(bpb, Math.ceil(end / bpb) * bpb), tr.notes.map(function (n) { return { start: n.start, len: n.duration, pitch: n.pitch, vel: n.velocity }; }), { name: file.name.replace(/\.midi?$/i, '') });
          (tr.controls || []).forEach(function (c) { clip.cc = clip.cc || {}; (clip.cc[c.controller] = clip.cc[c.controller] || []).push([c.start, c.value]); });
          ids.push(t.id);
        });
        q.bars = Math.max(q.bars, Math.ceil(M.endOfMusic(q) / M.beatsPerBar(q)) + 4);
      });
      if (ids[0]) app.selectTrack(ids[0]);
      U.status('Imported ' + file.name + ': ' + ids.length + (ids.length === 1 ? ' track.' : ' tracks.'), { undo: A.undo });
    }).catch(function (e) { U.status('That MIDI file could not be read: ' + e.message, { warning: true }); });
  }
  // A Standard MIDI File, written by Middaw's own writer (middaw/midi.py).
  A.exportMidi = function (clipOnly) {
    var p = app.project(), c = clipOnly ? app.clip() : null;
    var tracks = (c ? [app.track()] : p.tracks).map(function (t) {
      var notes = c ? c.notes.map(function (n) { return { start: n.start, duration: Math.min(n.len, c.length - n.start), pitch: n.pitch, velocity: n.vel }; })
                    : M.trackNotes(t).map(function (n) { return { start: n.start, duration: n.len, pitch: n.pitch, velocity: n.vel }; });
      var cc = [];
      (c ? [c] : t.clips).forEach(function (cl) { Object.keys(cl.cc || {}).forEach(function (num) { cl.cc[num].forEach(function (pt) { cc.push({ beat: (c ? 0 : cl.start) + pt[0], controller: Number(num), value: pt[1] }); }); }); });
      return { name: t.name, drums: t.drums, notes: notes, controls: cc };
    });
    fetch('/api/midi/write', { method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ tempo: p.tempo, meter: p.meter, key: M.keyInfo(p.key).label, tracks: tracks }) })
      .then(function (r) { if (!r.ok) throw new Error('the server did not write it'); return r.blob(); })
      .then(function (b) { download(b, (c ? (c.name || 'Clip') : fileName('')).trim() + '.mid'); U.status('Exported the MIDI file to your downloads.'); })
      .catch(function (e) { U.status('MIDI export needs Middaw’s server (python3 server/app.py): ' + e.message, { warning: true }); });
  };
  A.exportWav = function () {
    U.status('Rendering the song…');
    withStates().then(function (p) {
      var st = {};
      p.tracks.forEach(function (t) { st[t.id] = {}; [t.sound].concat(t.midiFx, t.audioFx).forEach(function (d) { if (d && d.state) st[t.id][d.id] = d.state; }); });
      return MD.audio.renderWav(p, st);
    }).then(function (blob) { download(blob, fileName('.wav')); U.status('Exported the audio to your downloads.'); })
      .catch(function (e) { console.error(e); U.status('The audio could not be rendered: ' + e.message, { warning: true }); });
  };

  // ------------------------------------------------------- recording ------
  // Record with the transport running takes what you play; with it stopped,
  // each note goes in at the caret, a grid step long, and the caret moves on.
  A.toggleRecord = function () {
    var btn = document.getElementById('record');
    if (recording) { finishRecording(); btn.setAttribute('aria-pressed', 'false'); return; }
    var t = app.project().tracks.find(function (x) { return x.arm; }) || app.track();
    if (!t) { U.status('Add a track to record into.'); return; }
    recording = { trackId: t.id, start: app.caret, notes: [], open: {}, step: !MD.audio.isPlaying() };
    btn.setAttribute('aria-pressed', 'true');
    U.status(recording.step ? 'Step input: play notes on your MIDI keyboard (or the keys beside the piano roll).' : 'Recording into ' + t.name + '.');
    if (!recording.step) MD.pass.event('take', 1);
  };
  function finishRecording() {
    var r = recording; recording = null;
    document.getElementById('record').setAttribute('aria-pressed', 'false');
    if (!r || r.step || !r.notes.length) return;
    var p = app.project(), bpb = M.beatsPerBar(p);
    var s = Math.floor(r.start / bpb) * bpb, e = Math.ceil(Math.max.apply(null, r.notes.map(function (n) { return n.start + n.len; })) / bpb) * bpb;
    var id = null;
    app.commit('Record', function (q) { id = M.placeNotes(q, r.trackId, s, Math.max(bpb, e - s), r.notes.map(function (n) { return { start: n.start - s, len: n.len, pitch: n.pitch, vel: n.vel }; }), { name: 'Recording' }).id; });
    app.selectClip(r.trackId, id);
    MD.pass.event('notes', r.notes.length);
  }
  function midiIn(data) {
    var st = data[0] & 0xF0, t = (recording && M.track(app.project(), recording.trackId)) || app.project().tracks.find(function (x) { return x.arm; }) || app.track();
    if (!t) return;
    MD.audio.init().then(function () { MD.audio.sync(app.project()); MD.audio.live(t.id, data); });
    MD.pass.input();
    var isOn = st === 0x90 && data[2] > 0, isOff = st === 0x80 || (st === 0x90 && data[2] === 0);
    if (isOn) held[data[1]] = true; else if (isOff) delete held[data[1]];
    if (!recording) return;
    if (recording.step) {
      if (!isOn) return;
      var grid = app.grid(), at = app.caret;
      A.insertBlock({ notes: [{ start: 0, len: grid, pitch: data[1], vel: data[2] }], beats: grid, name: 'Step' }, 'Step');
      app.setCaret(at + grid);
      return;
    }
    var beat = MD.audio.position();
    if (isOn) recording.open[data[1]] = { start: beat, pitch: data[1], vel: data[2] };
    else if (isOff && recording.open[data[1]]) {
      var n = recording.open[data[1]]; n.len = Math.max(1 / 32, beat - n.start); recording.notes.push(n); delete recording.open[data[1]];
    }
  }
  function setupMidi() {
    if (!navigator.requestMIDIAccess) return;
    navigator.requestMIDIAccess().then(function (access) {
      function hook() { access.inputs.forEach(function (inp) { inp.onmidimessage = function (e) { midiIn(Array.prototype.slice.call(e.data)); }; }); }
      hook(); access.onstatechange = hook;
    }).catch(function () {});
  }
  A.midiIn = midiIn;

  // ============================================================ toolbar ===
  function updateTransport() {
    var playing = MD.audio.isPlaying();
    var b = document.getElementById('play');
    b.textContent = playing ? '■' : '▶';
    b.setAttribute('aria-label', playing ? 'Stop' : 'Play');
    b.title = playing ? 'Stop (Space)' : 'Play from the caret (Space)';
    b.setAttribute('aria-pressed', String(playing));
  }
  function updateToolbar() {
    var p = app.project();
    var tempo = document.getElementById('tempo');
    if (document.activeElement !== tempo) tempo.value = p.tempo;
    document.getElementById('meter').textContent = p.meter[0] + '/' + p.meter[1];
    document.getElementById('key-name').textContent = M.keyInfo(p.key).label;
    document.getElementById('loop').setAttribute('aria-pressed', String(!!(p.loop && p.loop.on)));
    document.getElementById('follow').setAttribute('aria-pressed', String(app.view.follow));
    document.getElementById('mixer-toggle').setAttribute('aria-pressed', String(app.view.mixer));
    document.getElementById('click').setAttribute('aria-pressed', String(MD.audio.metronome()));
    document.title = (p.title || 'Untitled') + ' — Middaw';
    drawScaleView();
  }

  // ScaleView's icon: one octave as circles, the key's notes lit, what is
  // sounding ringed in the accent, and the chord it makes named beside it.
  function sounding() {
    var p = app.project(), pos = MD.audio.isPlaying() ? MD.audio.position() : null, out = {};
    Object.keys(held).forEach(function (k) { out[k] = true; });
    if (pos !== null) p.tracks.forEach(function (t) {
      if (t.drums || t.mute) return;
      M.trackNotes(t).forEach(function (n) { if (n.start <= pos && n.start + n.len > pos) out[n.pitch] = true; });
    });
    return Object.keys(out).map(Number);
  }
  var lastSounding = '';
  function drawScaleView() {
    var cv = document.getElementById('scaleview'), r = U.rem();
    var w = Math.round(3.6 * r), h = Math.round(1.72 * r), g = U.fit(cv, w, h);
    var key = M.keyInfo(app.project().key), now = sounding(), pcs = {};
    now.forEach(function (p) { pcs[p % 12] = true; });
    g.clearRect(0, 0, w, h);
    var rad = Math.min(w / 16, h / 4.6), white = [0, 2, 4, 5, 7, 9, 11], black = { 1: 0.5, 3: 1.5, 6: 3.5, 8: 4.5, 10: 5.5 };
    function dot(pc, x, y) {
      g.beginPath(); g.arc(x, y, rad, 0, Math.PI * 2);
      g.fillStyle = key.pcs[pc] ? U.css('--ink') : U.css('--control-held');
      g.fill();
      if (pcs[pc]) { g.lineWidth = Math.max(1.5, rad * 0.45); g.strokeStyle = U.css('--accent'); g.beginPath(); g.arc(x, y, rad + 1, 0, Math.PI * 2); g.stroke(); }
    }
    var step = w / 7;
    white.forEach(function (pc, i) { dot(pc, step * (i + 0.5), h * 0.72); });
    Object.keys(black).forEach(function (pc) { dot(Number(pc), step * (black[pc] + 0.5), h * 0.28); });
    // What you hold is named as you hold it; while the song plays, the chord
    // is the chords lane's - the accompaniment, not the tune's passing notes.
    var label = document.getElementById('chord-now'), keys = Object.keys(held).map(Number), text = '';
    if (keys.length >= 2 && MD.engines.isReady()) text = MD.engines.nameChord(keys, app.project().key) || '';
    else if (keys.length === 1) text = U.noteName(keys[0]);
    else if (MD.audio.isPlaying()) { var c = MD.arrange.chordAt(MD.audio.position()); text = c ? c.name : ''; }
    if (text !== lastSounding) { lastSounding = text; label.textContent = text; }
  }

  function meterMenu() {
    var choices = [[2, 4], [3, 4], [4, 4], [5, 4], [6, 8], [7, 8], [9, 8], [12, 8]];
    U.menu(document.getElementById('meter'), choices.map(function (m) {
      var p = app.project();
      return { label: m[0] + '/' + m[1], checked: p.meter[0] === m[0] && p.meter[1] === m[1], action: function () { app.commit('Change Time Signature', function (q) { q.meter = m; }); } };
    }));
  }
  function keySheet() {
    U.sheet('Key and Scale', function (b, close) {
      var p = app.project(), key = { root: p.key.root, scale: p.key.scale };
      function draw() {
        U.clear(b);
        b.appendChild(U.el('h4', { text: 'Key note' }));
        b.appendChild(U.el('div', { class: 'choices', role: 'radiogroup', 'aria-label': 'Key note' }, M.ROOT_NAMES.map(function (n, i) {
          return U.el('button', { type: 'button', role: 'radio', 'aria-checked': String(key.root === i + 1), 'aria-pressed': String(key.root === i + 1), onclick: function () { key.root = i + 1; draw(); } }, [n]);
        })));
        b.appendChild(U.el('h4', { text: 'Scale' }));
        b.appendChild(U.el('div', { class: 'choices', role: 'radiogroup', 'aria-label': 'Scale' }, M.SCALE_NAMES.map(function (n, i) {
          return U.el('button', { type: 'button', role: 'radio', 'aria-checked': String(key.scale === i + 1), 'aria-pressed': String(key.scale === i + 1), onclick: function () { key.scale = i + 1; draw(); } }, [n]);
        })));
        var names = MD.engines.noteNames(key), info = M.keyInfo(key);
        b.appendChild(U.el('p', { class: 'prose', text: info.intervals.map(function (iv) { return names[(info.tonic + iv) % 12]; }).join('  ') }));
        b.appendChild(U.el('div', { class: 'actions' }, [U.button('Cancel', close),
          U.button('Use ' + info.label, function () { app.commit('Change Key', function (q) { q.key = key; }); close(); }, { class: 'primary' })]));
      }
      draw();
    });
  }

  // ============================================================== menus ===
  var MAC = /Mac|iPhone|iPad/.test(navigator.platform);
  var CMD = MAC ? '⌘' : 'Ctrl+';
  function fileMenu(anchor) {
    U.menu(anchor, [
      { label: 'New…', keys: CMD + 'N', action: A.newSong },
      { label: 'Open…', keys: CMD + 'O', action: A.open },
      { label: 'Save', keys: CMD + 'S', action: A.save },
      { separator: true },
      { label: 'Import MIDI File…', action: A.open },
      { label: 'Export MIDI File', action: function () { A.exportMidi(false); } },
      { label: 'Export Audio (WAV)', action: A.exportWav },
      { separator: true },
      { label: 'This Song…', action: songSheet },
      { label: 'Battle Pass…', action: MD.pass.open }
    ]);
  }
  function editMenu(anchor) {
    var u = app.history.undoLabel(), r = app.history.redoLabel();
    U.menu(anchor, [
      { label: u ? 'Undo ' + u : 'Undo', keys: CMD + 'Z', disabled: !u, action: A.undo },
      { label: r ? 'Redo ' + r : 'Redo', keys: (MAC ? '⇧⌘' : 'Ctrl+Shift+') + 'Z', disabled: !r, action: A.redo },
      { separator: true },
      { label: 'Copy', keys: CMD + 'C', disabled: !app.clip(), action: A.copy },
      { label: 'Paste', keys: CMD + 'V', disabled: !clipboard, action: A.paste },
      { label: 'Duplicate', keys: CMD + 'D', disabled: !app.clip(), action: A.duplicate },
      { label: 'Split at the Caret', keys: CMD + 'E', disabled: !app.clip(), action: A.split },
      { label: 'Delete', keys: '⌫', action: A.deleteSelection },
      { label: 'Select All Notes', keys: CMD + 'A', disabled: !app.clip(), action: A.selectAll },
      { separator: true },
      { label: 'Quantize', keys: 'Q', disabled: !app.clip(), action: A.quantize },
      { label: 'Transform', disabled: !app.clip(), action: function () { A.transformMenu(anchor); } },
      { label: 'Generate…', keys: 'G', action: function () { MD.generate.open(); } }
    ]);
  }
  function viewMenu(anchor) {
    var size = MD.store.pref('textSize', 1);
    U.menu(anchor, [
      { heading: 'Text Size' }
    ].concat([1, 1.25, 1.5, 1.75, 2].map(function (s) {
      return { label: Math.round(s * 100) + '%', checked: Math.abs(size - s) < 0.01, keys: s === 1 ? CMD + '0' : null, action: function () { setTextSize(s); } };
    })).concat([
      { separator: true },
      { label: 'Browser', checked: !document.getElementById('workspace').classList.contains('no-browser'), keys: 'B', action: toggleBrowser },
      { label: 'Mixer', checked: app.view.mixer, keys: 'M', action: toggleMixer },
      { label: 'Full Score', checked: MD.score.full(), action: function () { MD.score.setFull(!MD.score.full()); showEditor('score'); } },
      { label: 'Light Score Page', checked: MD.score.light(), action: function () { MD.score.setLight(!MD.score.light()); } },
      { label: 'Follow the Music', checked: app.view.follow, keys: 'F', action: toggleFollow },
      { separator: true },
      { label: 'Keyboard Shortcuts', keys: 'H', action: keysSheet }
    ]));
  }
  function songSheet() {
    U.sheet('This Song', function (b, close) {
      var p = app.project();
      var title = U.el('input', { type: 'text', value: p.title, 'aria-label': 'Title' });
      var tempo = U.el('input', { type: 'number', min: 20, max: 300, value: p.tempo, 'aria-label': 'Tempo' });
      var bars = U.el('input', { type: 'number', min: 4, max: 999, value: p.bars, 'aria-label': 'Bars shown' });
      [['Title', title], ['Tempo', tempo], ['Bars', bars]].forEach(function (r) { b.appendChild(U.el('div', { class: 'rowline' }, [U.el('span', { class: 'lbl', text: r[0] }), r[1]])); });
      b.appendChild(U.el('div', { class: 'actions' }, [U.button('Cancel', close), U.button('Done', function () {
        app.commit('Change the Song', function (q) { q.title = title.value.trim() || 'Untitled'; q.tempo = Math.max(20, Math.min(300, +tempo.value || q.tempo)); q.bars = Math.max(4, +bars.value || q.bars); });
        close();
      }, { class: 'primary' })]));
    });
  }
  function keysSheet() {
    var rows = [['Space', 'Play or stop, from the caret'], ['Shift+Space', 'Play from bar 1'], ['Home / End', 'The start, the end of the music'],
      ['R', 'Record (stopped: step input)'], ['L', 'Loop'], ['C', 'Metronome'], ['F', 'Follow the music'], ['G', 'Generate'], ['M', 'Mixer'], ['B', 'Browser'],
      ['D', 'Draw tool'], ['1–6', 'Grid: a bar down to 1/32'], ['T', 'Triplets'], ['Q', 'Quantize'], ['↑ ↓', 'Notes up or down a semitone (Shift: an octave)'],
      ['← →', 'Notes a grid step earlier or later'], [CMD + 'Z', 'Undo'], [CMD + 'D', 'Duplicate'], [CMD + 'E', 'Split at the caret'],
      ['⌫', 'Delete'], ['Tab', 'Move between controls'], ['Esc', 'Let go of the chosen bars, a menu, a sheet'], [CMD + '= / ' + CMD + '-', 'Text size']];
    U.sheet('Keyboard Shortcuts', function (b, close) {
      var dl = U.el('dl', { class: 'facts' });
      rows.forEach(function (r) { dl.appendChild(U.el('dt', { text: r[0] })); dl.appendChild(U.el('dd', { text: r[1] })); });
      b.appendChild(dl);
      b.appendChild(U.el('div', { class: 'actions' }, [U.button('Done', close, { class: 'primary' })]));
    });
  }
  function setTextSize(s) {
    s = Math.max(1, Math.min(2, s));
    MD.store.setPref('textSize', s);
    document.documentElement.style.fontSize = (13 * s) + 'px';
    app.changed({ all: true });
  }
  function toggleBrowser() { document.getElementById('workspace').classList.toggle('no-browser'); app.changed({ all: true }); }
  function toggleFollow() { app.view.follow = !app.view.follow; MD.store.setPref('follow', app.view.follow); updateToolbar(); }
  function toggleMixer() {
    app.view.mixer = !app.view.mixer;
    showEditor(app.view.mixer ? 'mixer' : app.view.etab);
    updateToolbar();
  }
  function showEditor(which) {
    if (which !== 'mixer') { app.view.etab = which; app.view.mixer = false; }
    document.getElementById('roll').hidden = which !== 'roll';
    document.getElementById('roll').style.display = which === 'roll' ? '' : 'none';
    document.getElementById('score').hidden = which !== 'score';
    document.getElementById('mixer').hidden = which !== 'mixer';
    document.getElementById('roll-tools').style.visibility = which === 'roll' ? '' : 'hidden';
    document.querySelectorAll('[data-etab]').forEach(function (b) { b.setAttribute('aria-selected', String(b.dataset.etab === which)); });
    if (which === 'score') MD.score.draw();
    if (which === 'mixer') MD.mixer.render();
    if (which === 'roll') MD.roll.draw();
    updateToolbar();
  }

  // ============================================================= blocks ===
  // Starting Blocks as a toolbox (Miderator 0018): a kind, then a button per
  // degree of the key; click to hear it, Insert to put it at the caret.
  function renderBlocks() {
    var bar = document.getElementById('blocks-bar');
    U.clear(bar);
    if (!MD.engines.isReady() || app.view.etab !== 'roll' || app.view.mixer) return;
    if (!blocksSession) { blocksSession = new MD.engines.Session('starting-blocks'); }
    blocksSession.useKey(app.project().key);
    var p = app.project(), ctx = { root: p.key.root, scale: p.key.scale, num: p.meter[0], den: p.meter[1], barBeats: M.beatsPerBar(p), bpm: p.tempo,
      inst: 'pno', catalogueId: 'pno', bars: 1, selection: { notes: [], beats: 0, drums: false } };
    bar.appendChild(U.el('span', { class: 'label', text: 'Blocks' }));
    blocksSession.settings(ctx).forEach(function (s) {
      if (['cat', 'dia', 'bars', 'inv'].indexOf(s.id) < 0) return;
      var sel = U.el('select', { 'aria-label': 'Block ' + s.label.toLowerCase(), title: s.label });
      s.names.forEach(function (nm, i) { sel.appendChild(U.el('option', { value: i, text: nm, selected: i === s.index - 1 || null })); });
      sel.onchange = function () { blocksSession.set(s.id, Number(sel.value) + 1, ctx); renderBlocks(); };
      bar.appendChild(sel);
    });
    try { blocksResults = (blocksSession.generate(ctx, 1, 12).results || []); } catch (e) { blocksResults = []; }
    blocksResults.forEach(function (r) {
      var numeral = String(r.title || '').split(/\s+/)[0];
      bar.appendChild(U.button(numeral, function () { MD.audio.audition(r.parts, { tempo: p.tempo }); },
        { title: (r.detail || r.title) + ' - double-click to put it at the caret', ondblclick: function () { var n = []; r.parts.forEach(function (pt) { n = n.concat(pt.notes); }); A.insertBlock({ notes: n, beats: r.beats, name: r.title }, 'Block'); } }));
    });
  }

  // ========================================================== keyboard ===
  function typing() { var a = document.activeElement; return a && (a.tagName === 'INPUT' || a.tagName === 'TEXTAREA' || a.tagName === 'SELECT'); }
  function onKey(e) {
    var mod = e.metaKey || e.ctrlKey;
    if (e.key === 'Escape') {
      if (U.isMenuOpen()) { U.closeMenu(); return; }
      if (U.isSheetOpen()) { U.closeSheet(); return; }
      if (typing()) { document.activeElement.blur(); return; }
      if (app.sel.range || app.sel.notes.length) { app.sel.range = null; app.sel.notes = []; app.changed({ selection: true }); return; }
      if (document.activeElement && document.activeElement !== document.body) { document.activeElement.blur(); }
      return;
    }
    if (U.isSheetOpen() || U.isMenuOpen()) return;
    MD.pass.input();
    if (mod) {
      var k = e.key.toLowerCase();
      if (k === 'z' && !e.shiftKey) { e.preventDefault(); A.undo(); }
      else if ((k === 'z' && e.shiftKey) || k === 'y') { e.preventDefault(); A.redo(); }
      else if (k === 's') { e.preventDefault(); A.save(); }
      else if (k === 'o') { e.preventDefault(); A.open(); }
      else if (k === 'n') { e.preventDefault(); A.newSong(); }
      else if (typing()) return;
      else if (k === 'c') { e.preventDefault(); A.copy(); }
      else if (k === 'v') { e.preventDefault(); A.paste(); }
      else if (k === 'd') { e.preventDefault(); A.duplicate(); }
      else if (k === 'e') { e.preventDefault(); A.split(); }
      else if (k === 'a') { e.preventDefault(); A.selectAll(); }
      else if (k === 't') { e.preventDefault(); A.addInstrument('pno'); }
      else if (k === '=' || k === '+') { e.preventDefault(); setTextSize(MD.store.pref('textSize', 1) + 0.25); }
      else if (k === '-') { e.preventDefault(); setTextSize(MD.store.pref('textSize', 1) - 0.25); }
      else if (k === '0') { e.preventDefault(); setTextSize(1); }
      return;
    }
    if (typing()) return;
    var onButton = document.activeElement && document.activeElement.tagName === 'BUTTON';
    switch (e.key) {
      case ' ': if (onButton) return; e.preventDefault(); A.toggle(e.shiftKey); break;
      case 'Home': e.preventDefault(); A.toStart(); break;
      case 'End': e.preventDefault(); A.toEnd(); break;
      case 'Backspace': case 'Delete': e.preventDefault(); A.deleteSelection(); break;
      case 'ArrowUp': if (app.clip()) { e.preventDefault(); A.transpose(e.shiftKey ? 12 : 1); } break;
      case 'ArrowDown': if (app.clip()) { e.preventDefault(); A.transpose(e.shiftKey ? -12 : -1); } break;
      case 'ArrowLeft': if (app.sel.notes.length) { e.preventDefault(); A.nudge(-app.grid()); } break;
      case 'ArrowRight': if (app.sel.notes.length) { e.preventDefault(); A.nudge(app.grid()); } break;
      default: {
        var k2 = e.key.toLowerCase();
        if (k2 === 'r') A.toggleRecord();
        else if (k2 === 'l') toggleLoop();
        else if (k2 === 'c') { MD.audio.setMetronome(!MD.audio.metronome()); updateToolbar(); }
        else if (k2 === 'f') toggleFollow();
        else if (k2 === 'g') { if (app.view.itab === 'generate') A.inspectorTab('track'); else MD.generate.open(); }
        else if (k2 === 'm') toggleMixer();
        else if (k2 === 'b') toggleBrowser();
        else if (k2 === 'd') setTool(app.view.tool === 'draw' ? 'select' : 'draw');
        else if (k2 === 't') setTriplet(!app.view.triplet);
        else if (k2 === 'q') A.quantize();
        else if (k2 === 'h') keysSheet();
        else if (/^[1-6]$/.test(k2)) setGrid([4, 2, 1, 0.5, 0.25, 0.125][Number(k2) - 1]);
      }
    }
  }
  function toggleLoop() {
    var p = app.project();
    app.commit(p.loop.on ? 'Loop Off' : 'Loop On', function (q) {
      if (app.sel.range && !q.loop.on) q.loop = { on: true, start: app.sel.range.start, end: app.sel.range.end };
      else if (!q.loop.on && !(q.loop.end > q.loop.start)) q.loop = { on: true, start: 0, end: 4 * M.beatsPerBar(q) };
      else q.loop.on = !q.loop.on;
    });
    if (MD.audio.isPlaying()) A.play(MD.audio.position());
  }
  function setTool(t) { app.view.tool = t; document.getElementById('tool-draw').setAttribute('aria-pressed', String(t === 'draw')); MD.roll.draw(); }
  function setGrid(g) { app.view.grid = g; document.getElementById('grid').value = String(g); MD.roll.draw(); }
  function setTriplet(on) { app.view.triplet = on; document.getElementById('triplet').setAttribute('aria-pressed', String(on)); MD.roll.draw(); }

  // ================================================================ loop ===
  var lastPos = -1;
  function frame() {
    if (MD.audio.isPlaying()) {
      MD.arrange.follow(); MD.roll.follow();
      var pos = MD.audio.position();
      document.getElementById('position').textContent = M.formatPosition(app.project(), pos);
      MD.arrange.drawRuler(); MD.arrange.drawTimeline(); MD.roll.draw();
      if (app.view.etab === 'score' && Math.floor(pos * 4) !== Math.floor(lastPos * 4)) MD.score.draw();
      lastPos = pos;
      drawScaleView();
    } else if (Object.keys(held).length || lastSounding) drawScaleView();
    requestAnimationFrame(frame);
  }

  // ================================================================ boot ===
  function setupReturn() {
    var p = app.history.project;
    if (!p.returns || !p.returns.length) {
      var rev = D.make('reverberator'); rev.sliders = { 1: 5, 2: 100, 3: 140, 4: 120 };
      p.returns = [{ id: 'return', name: 'Reverb', audioFx: [rev] }];
    }
  }

  function wire() {
    U.initStatus();
    document.querySelectorAll('.menu-button').forEach(function (b) {
      b.onclick = function () { ({ file: fileMenu, edit: editMenu, view: viewMenu })[b.dataset.menu](b); };
    });
    document.getElementById('play').onclick = function () { A.toggle(false); };
    document.getElementById('to-start').onclick = A.toStart;
    document.getElementById('record').onclick = A.toggleRecord;
    document.getElementById('loop').onclick = toggleLoop;
    document.getElementById('click').onclick = function () { MD.audio.init().then(function () { MD.audio.setMetronome(!MD.audio.metronome()); updateToolbar(); }); };
    document.getElementById('follow').onclick = toggleFollow;
    document.getElementById('mixer-toggle').onclick = toggleMixer;
    document.getElementById('generate-open').onclick = function () { if (app.view.itab === 'generate') A.inspectorTab('track'); else MD.generate.open(); };
    document.getElementById('pass').onclick = MD.pass.open;
    document.getElementById('meter').onclick = meterMenu;
    document.getElementById('key').onclick = keySheet;
    var tempo = document.getElementById('tempo');
    tempo.onchange = function () { var v = Math.max(20, Math.min(300, Math.round(+tempo.value))); if (v) app.commit('Change Tempo', function (q) { q.tempo = v; }); if (MD.audio.isPlaying()) A.play(MD.audio.position()); };
    document.getElementById('add-track').onclick = function (e) {
      U.menu(e.currentTarget, [{ heading: 'Add a track for' }].concat(['pno', 'synth', 'kit', 'vln1', 'vla', 'vc', 'fl', 'cl', 'tpt', 'hn', 'gtr', 'ebass'].map(function (id) {
        var i = instrumentById(id);
        return { label: i ? i.name : id, action: function () { A.addInstrument(id); } };
      })).concat([{ separator: true }, { label: 'An Ensemble…', action: function () { MD.browser.setTab('sounds'); document.getElementById('workspace').classList.remove('no-browser'); } }]));
    };
    document.querySelectorAll('#inspector [role=tab]').forEach(function (b) { b.onclick = function () { A.inspectorTab(b.dataset.itab); }; });
    document.querySelectorAll('[data-etab]').forEach(function (b) { b.onclick = function () { showEditor(b.dataset.etab); renderBlocks(); }; });
    document.getElementById('tool-draw').onclick = function () { setTool(app.view.tool === 'draw' ? 'select' : 'draw'); };
    document.getElementById('grid').onchange = function (e) { setGrid(Number(e.target.value)); };
    document.getElementById('triplet').onclick = function () { setTriplet(!app.view.triplet); };
    document.getElementById('quantize').onclick = A.quantize;
    document.getElementById('lane').onchange = function (e) { app.view.lane = e.target.value; MD.roll.draw(); };
    document.getElementById('welcome-form').onsubmit = function (e) {
      e.preventDefault();
      var prompt = document.getElementById('welcome-prompt').value;
      MD.generate.lastPrompt = prompt;
      MD.generate.open('compose');
      MD.generate.compose(prompt).then(function (d) { if (d) MD.generate.insertComposed(true); });
    };
    document.getElementById('welcome-new').onclick = A.newSong;
    document.getElementById('welcome-open').onclick = A.open;
    // the divider between the tracks and the editor
    var div = document.getElementById('divider');
    div.onmousedown = function (e) {
      var arr = document.getElementById('arrange'), y0 = e.clientY, h0 = arr.offsetHeight;
      function mv(ev) { arr.style.flex = '0 0 ' + Math.max(90, h0 + ev.clientY - y0) + 'px'; }
      function up() { window.removeEventListener('mousemove', mv); window.removeEventListener('mouseup', up); app.changed({ view: true }); }
      window.addEventListener('mousemove', mv); window.addEventListener('mouseup', up);
    };
    div.onkeydown = function (e) {
      var arr = document.getElementById('arrange');
      if (e.key === 'ArrowUp' || e.key === 'ArrowDown') { e.preventDefault(); arr.style.flex = '0 0 ' + Math.max(90, arr.offsetHeight + (e.key === 'ArrowUp' ? -24 : 24)) + 'px'; app.changed({ view: true }); }
    };
    // drop a MIDI or Middaw file anywhere
    window.addEventListener('dragover', function (e) { if (e.dataTransfer && Array.prototype.indexOf.call(e.dataTransfer.types, 'Files') >= 0) e.preventDefault(); });
    window.addEventListener('drop', function (e) {
      if (e.defaultPrevented) return;
      var f = e.dataTransfer && e.dataTransfer.files[0];
      if (f && /\.(midi?|middaw|json)$/i.test(f.name)) { e.preventDefault(); openFile(f); }
    });
    window.addEventListener('keydown', onKey);
    window.addEventListener('mousedown', function () { MD.pass.input(); }, true);
    document.addEventListener('pointerdown', function first() { MD.audio.init().then(function () { MD.audio.sync(app.project()); MD.samples.loadAll(app.project()); }); document.removeEventListener('pointerdown', first); });
    MD.audio.on('error', function (id, msg) { U.status('A device stopped: ' + msg, { warning: true }); });
    MD.audio.on('transport', updateTransport);
  }

  function boot() {
    var saved = MD.store.restore();
    app.history = new M.History(saved && saved.tracks ? saved : M.newProject());
    setupReturn();
    app.view.follow = MD.store.pref('follow', true);
    setTextSize(MD.store.pref('textSize', 1));
    var autosave = null;
    app.history.on(function () {
      clearTimeout(autosave);
      autosave = setTimeout(function () { MD.store.autosave(app.project()); }, 400);
      if (MD.audio.context()) MD.audio.sync(app.project());
      MD.pass.event('edit', 1);
    });
    wire();
    U.status('Loading the engines…');
    Promise.all([MD.engines.load('engines/'), D.load('devices/')]).then(function () {
      MD.arrange.init(); MD.roll.init(); MD.score.init(); MD.inspector.init(); MD.generate.init(); MD.browser.init(); MD.mixer.init();
      app.validate();
      app.on(function (w) { updateToolbar(); if (w.all || w.project || w.selection) renderBlocks(); });
      app.on(function () { MD.audio.sync(app.project()); });
      showEditor('roll');
      new ResizeObserver(function () {
        if (app.view.mixer) return;
        if (app.view.etab === 'score') MD.score.draw(); else MD.roll.draw();
      }).observe(document.getElementById('editor-body'));
      app.changed({ all: true });
      MD.browser.render();
      MD.inspector.render();
      U.status('');
      MD.pass.start();
      setupMidi();
      requestAnimationFrame(frame);
    }).catch(function (e) {
      console.error(e);
      U.status('Middaw could not start: ' + e.message, { warning: true });
    });
  }

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot); else boot();
})(globalThis.MD = globalThis.MD || {});
