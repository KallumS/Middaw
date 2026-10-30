/* The inspector: the chosen track, top to bottom in the order sound flows.
 *
 *   Instrument   which instrument of the orchestra the part is for - its
 *                range, how fast and wide it plays (Midi Catalogue's table)
 *   Sound        what plays it, and that device's controls
 *   MIDI Effects AutoCC, Midi Evolver, MIDI Production Center
 *   Audio Effects Reverberator
 *   Mix          level, pan, the reverb send
 *   Clip         the chosen clip, and what can be done with it
 *   About        the Orchestration Helper's entry for the instrument
 *
 * A device's controls are its own sliders, named as the JSFX names them.
 */
(function (MD) {
  'use strict';
  var app = MD.app, M = MD.model, U = MD.ui, D = MD.devices;
  var body, openMore = {};

  function synthName(p) { return (globalThis.MiddawSynths.PRESET_NAMES[p] || 'Synth'); }
  MD.synthName = synthName;

  function section(title, kids, opts) {
    opts = opts || {};
    var s = U.el('section', { class: 'section' });
    if (title) s.appendChild(U.el('h2', {}, [U.el('span', { text: title })].concat(opts.right ? [opts.right] : [])));
    kids.forEach(function (k) { if (k) s.appendChild(k); });
    return s;
  }
  function rowline(label, control) { return U.el('div', { class: 'rowline' }, [U.el('span', { class: 'lbl', text: label }), control]); }
  function select(options, value, onchange, attrs) {
    var s = U.el('select', attrs || {});
    options.forEach(function (o) {
      if (o.group) {
        var og = U.el('optgroup', { label: o.group });
        o.items.forEach(function (it) { og.appendChild(U.el('option', { value: it.value, text: it.label, selected: String(it.value) === String(value) || null })); });
        s.appendChild(og);
      } else s.appendChild(U.el('option', { value: o.value, text: o.label, selected: String(o.value) === String(value) || null }));
    });
    s.onchange = function () { onchange(s.value); };
    return s;
  }
  function disclosure(id, title, summary, build) {
    var open = !!openMore[id];
    var btn = U.el('button', { type: 'button', class: 'disclosure', 'aria-expanded': String(open),
      onclick: function () { openMore[id] = !openMore[id]; render(); } },
      [U.el('span', { text: title }), summary ? U.el('span', { class: 'summary', text: summary }) : null]);
    var wrap = U.el('div', {}, [btn]);
    if (open) wrap.appendChild(build());
    return wrap;
  }

  // ------------------------------------------------------- the sliders ---
  function sliderValue(dev, sl) { var v = dev.sliders && dev.sliders[sl.index]; return v === undefined ? sl.def : v; }
  function formatValue(sl, v) {
    if (sl.names) return sl.names[Math.round(v - sl.min)] || String(v);
    var unit = (/\(([^)]+)\)\s*$/.exec(sl.name) || [])[1] || '';
    var digits = sl.step && sl.step < 1 ? Math.min(2, String(sl.step).split('.')[1].length) : 0;
    return v.toFixed(digits) + (unit === '%' ? '%' : unit ? ' ' + unit.replace(/^semitones$/, 'st') : '');
  }
  function plainName(sl) { return sl.name.replace(/\s*\([^)]*\)\s*$/, ''); }
  // Where the value sits on the control: log-shaped sliders feel as they do in REAPER.
  function toPos(sl, v) {
    if (sl.shape && sl.shape.kind === 'log' && sl.min > 0) return Math.log(v / sl.min) / Math.log(sl.max / sl.min);
    return (v - sl.min) / ((sl.max - sl.min) || 1);
  }
  function fromPos(sl, x) {
    var v = (sl.shape && sl.shape.kind === 'log' && sl.min > 0) ? sl.min * Math.pow(sl.max / sl.min, x) : sl.min + x * (sl.max - sl.min);
    if (sl.step) v = Math.round(v / sl.step) * sl.step;
    return Math.max(sl.min, Math.min(sl.max, +v.toFixed(6)));
  }

  function setSlider(where, dev, n, v, commit) {
    var t = app.track();
    MD.audio.slider(where === 'return' ? 'return' : t.id, dev.id, n, v);
    if (commit) app.commit('Change ' + plainName(D.slider(dev.device, n) || { name: 'Setting' }), function (q) {
      var d = findDevice(q, where, dev.id);
      if (d) { d.sliders = d.sliders || {}; d.sliders[n] = v; }
    });
  }
  function findDevice(q, where, id) {
    if (where === 'return') return (q.returns[0].audioFx || []).find(function (d) { return d.id === id; });
    var t = M.track(q, app.sel.trackId);
    if (!t) return null;
    if (t.sound && t.sound.id === id) return t.sound;
    return (t.midiFx.concat(t.audioFx)).find(function (d) { return d.id === id; });
  }

  function control(where, dev, n) {
    var sl = D.slider(dev.device, n);
    if (!sl) return null;
    var v = sliderValue(dev, sl);
    var name = plainName(sl);
    if (sl.names && sl.names.length === 2 && /^(off|no)$/i.test(sl.names[0])) {
      return U.el('div', { class: 'rowline' }, [U.el('span', { class: 'lbl', text: name }),
        U.toggle(sl.names[1] === 'On' || sl.names[1] === 'Yes' ? (v ? 'On' : 'Off') : sl.names[v ? 1 : 0], !!v, function () { setSlider(where, dev, n, v ? 0 : 1, true); },
          { 'aria-label': name })]);
    }
    if (sl.names) {
      var opts = sl.names.map(function (nm, i) { return { value: sl.min + i, label: nm }; });
      return rowline(name, select(opts, v, function (x) { setSlider(where, dev, n, Number(x), true); }, { 'aria-label': name }));
    }
    var out = U.el('output', { text: formatValue(sl, v) });
    var range = U.el('input', { type: 'range', min: 0, max: 1000, step: 1, value: Math.round(toPos(sl, v) * 1000), 'aria-label': name,
      'aria-valuetext': formatValue(sl, v) });
    range.oninput = function () { var x = fromPos(sl, range.value / 1000); out.textContent = formatValue(sl, x); range.setAttribute('aria-valuetext', out.textContent); setSlider(where, dev, n, x, false); };
    range.onchange = function () { setSlider(where, dev, n, fromPos(sl, range.value / 1000), true); };
    range.ondblclick = function () { setSlider(where, dev, n, sl.def, true); };
    return U.el('div', { class: 'param', title: 'Double-click for the default' }, [U.el('span', { class: 'lbl', text: name }), range, out]);
  }
  function controls(where, dev, list) { return U.el('div', {}, (list || []).map(function (n) { return control(where, dev, n); }).filter(Boolean)); }

  // --------------------------------------------------------- a device ----
  function devicePanel(where, dev, opts) {
    opts = opts || {};
    var d = D.DEVICES[dev.device];
    var head = U.el('header', {}, [U.el('h3', { text: d.name })].concat(opts.remove ? [
      U.button('Remove', opts.remove, { title: 'Remove ' + d.name, 'aria-label': 'Remove ' + d.name })] : []));
    var box = U.el('div', { class: 'device' }, [head]);
    var t = app.track();
    switch (dev.device) {
      case 'synth': {
        var names = globalThis.MiddawSynths.PRESET_NAMES;
        box.appendChild(rowline('Preset', select(Object.keys(names).map(function (k) { return { value: k, label: names[k] }; }), dev.preset || 'keys',
          function (v) { app.commit('Change Sound', function (q) { M.track(q, t.id).sound.preset = v; }); }, { 'aria-label': 'Synth preset' })));
        break;
      }
      case 'kit': box.appendChild(U.el('p', { class: 'note-line', text: 'General MIDI drums on channel 10.' })); break;
      case 'sampler': box.appendChild(sampleDrop(dev, 0, 'Add a Sound\u2026'));
        if (dev.sample) box.appendChild(rowline('Its pitch', select(rootOptions(), dev.sample.root, function (v) {
          app.commit('Set Root Note', function (q) { M.track(q, t.id).sound.sample.root = Number(v); });
          var s = app.track().sound; MD.samples.send(t.id, s.id, s.sample, null);
        }, { 'aria-label': 'Root note of the sound' })));
        break;
      case 'creator': {
        var presets = d.presets || [];
        box.appendChild(rowline('Instrument', select([{ value: -1, label: 'Your Own Instrument' }].concat(presets.map(function (p, i) { return { value: i, label: p.name }; })),
          dev.presetIndex === undefined ? -1 : dev.presetIndex, function (v) { applyCreatorPreset(dev, Number(v)); }, { 'aria-label': 'Instrument Creator preset' })));
        box.appendChild(U.el('div', { class: 'rowline' }, [U.button('Surprise Me', function () { surprise(dev); }, { title: 'Pick every part at random' }),
          U.button('Play C4', function () { MD.audio.init().then(function () { MD.audio.live(t.id, [0x90, 60, 100]); setTimeout(function () { MD.audio.live(t.id, [0x80, 60, 0]); }, 700); }); })]));
        box.appendChild(controls(where, dev, d.main));
        box.appendChild(disclosure('parts-' + dev.id, 'Parts', '', function () { return controls(where, dev, d.parts); }));
        box.appendChild(disclosure('more-' + dev.id, 'More', '', function () { return controls(where, dev, d.more); }));
        return box;
      }
      case 'shuffler':
        box.appendChild(sampleDrop(dev, 0, 'Add Sample A\u2026'));
        box.appendChild(sampleDrop(dev, 1, 'Add Sample B\u2026'));
        box.appendChild(controls(where, dev, d.main));
        box.appendChild(disclosure('more-' + dev.id, 'More', '', function () { return controls(where, dev, d.more); }));
        return box;
      case 'autocc':
        box.appendChild(controls(where, dev, d.main));
        box.appendChild(disclosure('lanes-' + dev.id, 'Lanes', '', function () { return controls(where, dev, d.lanes); }));
        box.appendChild(disclosure('more-' + dev.id, 'More', '', function () { return controls(where, dev, d.more); }));
        box.appendChild(U.el('div', { class: 'rowline' }, [U.button('Draw into the Clip', function () { MD.actions.seedCC(); },
          { title: 'Write the curves AutoCC plays into the chosen clip’s controller lanes', disabled: !app.clip() || null })]));
        return box;
      case 'evolver':
        box.appendChild(controls(where, dev, d.main));
        box.appendChild(U.el('div', { class: 'choices', role: 'group', 'aria-label': 'Layers' }, d.layers.map(function (n) {
          var sl = D.slider('evolver', n), v = sliderValue(dev, sl);
          return U.toggle(plainName(sl), !!v, function () { setSlider(where, dev, n, v ? 0 : 1, true); });
        })));
        box.appendChild(disclosure('more-' + dev.id, 'More', '', function () { return controls(where, dev, d.more); }));
        box.appendChild(U.el('div', { class: 'rowline' }, [
          U.button('Insert the Take', function () { MD.actions.evolverTake(dev); }, { title: 'Put what Midi Evolver last played into this track at the caret' }),
          U.button('Panic', function () { MD.audio.eval(t.id, dev.id, 'midi_panic ? midi_panic() : 0;'); MD.audio.live(t.id, [0xB0, 123, 0]); }, { title: 'Stop every note it started' })]));
        return box;
      case 'mpc':
        box.appendChild(U.el('div', { class: 'rowline' }, [
          U.button('Load the Chosen Clip', function () { MD.actions.mpcLoad(dev); }, { disabled: !app.clip() || null, title: 'Chop the chosen clip onto the pads' }),
          U.button('Transfer to Pads', function () { MD.audio.eval(t.id, dev.id, 'ui_req_xfer = 1;'); U.status('Chops transferred to bank A.'); })]));
        box.appendChild(controls(where, dev, d.main));
        var pads = U.el('div', { class: 'pads', role: 'group', 'aria-label': 'Pads' });
        for (var row = 3; row >= 0; row--) for (var col = 0; col < 4; col++) (function (k) {
          var b = U.button(String(k + 1), null, { 'aria-label': 'Pad ' + (k + 1) });
          b.onmousedown = function () { MD.audio.init().then(function () { MD.audio.live(t.id, [0x90, 36 + k, 110]); }); };
          b.onmouseup = b.onmouseleave = function () { MD.audio.live(t.id, [0x80, 36 + k, 0]); };
          pads.appendChild(b);
        })(row * 4 + col);
        box.appendChild(pads);
        ['Filter', 'EQ', 'Compressor', 'Delay', 'Stutter', 'Pitch Correct'].forEach(function (fxName, i) {
          var list = d.fx[i];
          var onSl = D.slider('mpc', list[0]), on = sliderValue(dev, onSl);
          box.appendChild(disclosure('mpcfx-' + i + dev.id, fxName, on ? 'On' : 'Off', function () { return controls(where, dev, list); }));
        });
        box.appendChild(disclosure('more-' + dev.id, 'Setup', '', function () { return controls(where, dev, d.more); }));
        return box;
      case 'reverberator':
        box.appendChild(controls(where, dev, d.main));
        box.appendChild(disclosure('more-' + dev.id, 'More', '', function () { return controls(where, dev, d.more); }));
        return box;
    }
    return box;
  }

  function rootOptions() {
    var o = [];
    for (var p = 36; p <= 84; p++) o.push({ value: p, label: U.noteName(p) });
    return o;
  }
  function applyCreatorPreset(dev, k) {
    var t = app.track(), pr = (D.DEVICES.creator.presets || [])[k];
    app.commit('Choose an Instrument', function (q) {
      var d = findDevice(q, 'track', dev.id);
      d.presetIndex = k;
      if (pr) { d.presetName = pr.name; pr.values.forEach(function (v, j) { d.sliders[j + 1] = v; }); }
      else d.presetName = null;
    });
    if (pr) pr.values.forEach(function (v, j) { MD.audio.slider(t.id, dev.id, j + 1, v); });
  }
  function surprise(dev) {
    var t = app.track(), vals = {};
    D.DEVICES.creator.parts.forEach(function (n) {
      var sl = D.slider('creator', n);
      vals[n] = sl.min + Math.floor(Math.random() * (sl.names ? sl.names.length : (sl.max - sl.min + 1)));
    });
    app.commit('Surprise Me', function (q) {
      var d = findDevice(q, 'track', dev.id); d.presetIndex = -1; d.presetName = null;
      Object.keys(vals).forEach(function (n) { d.sliders[n] = vals[n]; });
    });
    Object.keys(vals).forEach(function (n) { MD.audio.slider(t.id, dev.id, Number(n), vals[n]); });
  }

  // A drop zone for a sound file: the Instant Instrument's one, Transient
  // Shuffler's A and B.
  function sampleDrop(dev, slot, label) {
    var t = app.track();
    var have = dev.device === 'sampler' ? dev.sample : (dev.samples && dev.samples[slot]);
    var z = U.el('div', { class: 'drop', role: 'button', tabindex: '0', text: have ? (have.name || 'A sound') : label, title: 'Drop a sound here, or click to choose one' });
    function take(file) {
      MD.samples.fromFile(file).then(function (s) {
        app.commit('Load a Sound', function (q) {
          var d = findDevice(q, 'track', dev.id);
          if (d.device === 'sampler') { s.root = 60; d.sample = s; }
          else { d.samples = d.samples || []; d.samples[slot] = s; }
        });
        var fresh = findDevice(app.project(), 'track', dev.id);
        MD.samples.load(t.id, fresh);
        U.status('Loaded ' + s.name + '.');
      }).catch(function (e) { U.status('That file could not be read as a sound: ' + e.message, { warning: true }); });
    }
    z.ondragover = function (e) { e.preventDefault(); z.classList.add('over'); };
    z.ondragleave = function () { z.classList.remove('over'); };
    z.ondrop = function (e) { e.preventDefault(); z.classList.remove('over'); if (e.dataTransfer.files[0]) take(e.dataTransfer.files[0]); };
    var pick = function () {
      var inp = document.getElementById('file-sample');
      inp.value = '';
      inp.onchange = function () { if (inp.files[0]) take(inp.files[0]); };
      inp.click();
    };
    z.onclick = pick;
    z.onkeydown = function (e) { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); pick(); } };
    return z;
  }

  // --------------------------------------------------------- sections ----
  function instrumentSection(t) {
    var list = MD.engines.instruments(), fams = {};
    list.forEach(function (i) { (fams[i.family] = fams[i.family] || []).push({ value: i.id, label: i.name }); });
    var opts = Object.keys(fams).map(function (f) { return { group: f, items: fams[f] }; });
    opts.push({ group: 'Other', items: [{ value: 'kit', label: 'Drum Kit' }, { value: 'synth', label: 'Synth' }] });
    var inst = MD.roll.instrumentOf(t);
    var facts = inst ? U.el('p', { class: 'note-line', text: U.noteName(inst.low) + ' to ' + U.noteName(inst.high) +
      (inst.sweet ? ', best ' + U.noteName(inst.sweet[0]) + '–' + U.noteName(inst.sweet[1]) : '') +
      (inst.poly > 1 ? ', ' + inst.poly + ' notes at once' : ', one note at a time') }) : null;
    var name = U.el('input', { type: 'text', value: t.name, 'aria-label': 'Track name' });
    name.onchange = function () { var v = name.value.trim(); if (v) app.commit('Rename Track', function (q) { M.track(q, t.id).name = v; }); };
    return section(null, [
      rowline('Name', name),
      rowline('Instrument', select(opts, t.instrument, function (v) { MD.actions.setInstrument(t.id, v); }, { 'aria-label': 'Instrument' })),
      facts
    ]);
  }

  function soundSection(t) {
    var instruments = ['synth', 'kit', 'sampler', 'creator', 'shuffler'];
    var sel = select(instruments.map(function (k) { return { value: k, label: D.DEVICES[k].name }; }), t.sound.device, function (v) {
      app.commit('Change Instrument', function (q) {
        var x = M.track(q, t.id);
        x.sound = D.make(v, v === 'synth' ? { preset: D.PRESET_FOR[x.instrument] || 'keys' } : (v === 'creator' ? {} : {}));
        if (v === 'creator') { var pr = D.DEVICES.creator.presets[1]; x.sound.presetIndex = 1; x.sound.presetName = pr.name; pr.values.forEach(function (val, j) { x.sound.sliders[j + 1] = val; }); }
        if (v === 'kit') x.drums = true;
      });
    }, { 'aria-label': 'What plays this track' });
    return section('Sound', [rowline('Played by', sel), devicePanel('track', t.sound)]);
  }

  function chainSection(t, kind) {
    var list = kind === 'midi' ? t.midiFx : t.audioFx;
    var choices = Object.keys(D.DEVICES).filter(function (k) { return D.DEVICES[k].type === kind; });
    var add = U.button(kind === 'midi' ? 'Add MIDI Effect' : 'Add Audio Effect', function (e) {
      U.menu(add, choices.map(function (k) {
        return { label: D.DEVICES[k].name, action: function () { MD.actions.addDevice(t.id, k); } };
      }));
    }, { 'aria-haspopup': 'menu' });
    var kids = list.map(function (dev) {
      return devicePanel('track', dev, { remove: function () {
        app.commit('Remove ' + D.DEVICES[dev.device].name, function (q) {
          var x = M.track(q, t.id);
          x.midiFx = x.midiFx.filter(function (d) { return d.id !== dev.id; });
          x.audioFx = x.audioFx.filter(function (d) { return d.id !== dev.id; });
        });
      } });
    });
    return section(kind === 'midi' ? 'MIDI Effects' : 'Audio Effects', kids.concat([U.el('div', { class: 'rowline' }, [add])]));
  }

  function mixSection(t) {
    function slider(label, value, min, max, step, fmt, set) {
      var out = U.el('output', { text: fmt(value) });
      var r = U.el('input', { type: 'range', min: min, max: max, step: step, value: value, 'aria-label': label, 'aria-valuetext': fmt(value) });
      r.oninput = function () { out.textContent = fmt(+r.value); set(+r.value, false); };
      r.onchange = function () { set(+r.value, true); };
      return U.el('div', { class: 'param' }, [U.el('span', { class: 'lbl', text: label }), r, out]);
    }
    function mixSet(field, label) {
      return function (v, commit) {
        // heard while dragging, kept (and undoable) when let go
        if (commit) app.commit(label, function (q) { M.track(q, t.id)[field] = v; });
        else { var mix = {}; mix[field] = v; MD.audio.setMix(t.id, mix); }
      };
    }
    return section('Mix', [
      slider('Level', t.volume, 0, 1, 0.01, dbText, mixSet('volume', 'Change Level')),
      slider('Pan', t.pan, -1, 1, 0.01, panText, mixSet('pan', 'Change Pan')),
      slider('Reverb', t.send || 0, 0, 1, 0.01, function (v) { return Math.round(v * 100) + '%'; }, mixSet('send', 'Change Reverb Send'))
    ]);
  }
  function dbText(v) { if (v <= 0) return '-inf'; var db = (v - 0.8) * 60; return (db > 0 ? '+' : '') + db.toFixed(1) + ' dB'; }
  function panText(v) { return Math.abs(v) < 0.005 ? 'Centre' : (v < 0 ? 'L' : 'R') + Math.round(Math.abs(v) * 100); }
  MD.mixText = { db: dbText, pan: panText };

  function clipSection(t, c) {
    var p = app.project(), bpb = M.beatsPerBar(p);
    var src = c.source ? U.el('p', { class: 'note-line', text: 'Made with ' + c.source.generator + (c.source.title ? ': ' + c.source.title : '') }) : null;
    var name = U.el('input', { type: 'text', value: c.name || '', placeholder: 'Untitled', 'aria-label': 'Clip name' });
    name.onchange = function () { app.commit('Rename Clip', function (q) { M.clipById(q, c.id).clip.name = name.value.trim(); }); };
    return section('Clip', [
      rowline('Name', name),
      U.el('p', { class: 'note-line', text: 'Bar ' + (Math.floor(c.start / bpb) + 1) + ', ' + fmtBars(c.length / bpb) + ', ' + c.notes.length + ' notes' }),
      src,
      U.el('div', { class: 'choices' }, [
        U.button('Vary…', function () { MD.generate.open('midi-variator'); }, { title: 'Variations of this clip (Midi Variator)' }),
        U.button('Suggest…', function () { MD.generate.open('midi-suggester'); }, { title: 'Chords for a tune, or a tune for chords (Midi Suggester)' }),
        U.button('Transform', function (e) { MD.actions.transformMenu(e.currentTarget); }, { 'aria-haspopup': 'menu' })
      ])
    ]);
  }
  function fmtBars(b) { b = Math.round(b * 100) / 100; return b + (b === 1 ? ' bar' : ' bars'); }

  // The Orchestration Helper's entry for this instrument.
  var ORCH_ID = { vln1: 'violin', vln2: 'violin', vla: 'viola', vc: 'cello', cb: 'doublebass', picc: 'piccolo', fl: 'flute',
    ob: 'oboe', eh: 'englishhorn', cl: 'clarinet', bcl: 'bassclarinet', bsn: 'bassoon', cbsn: 'contrabassoon', hn: 'horn',
    tpt: 'trumpet', tbn: 'trombone', btbn: 'basstrombone', tba: 'tuba', timp: 'timpani', glock: 'glockenspiel', xyl: 'xylophone',
    mar: 'marimba', harp: 'harp', cel: 'celesta', pno: 'piano' };
  function orchEntry(t) {
    var o = MD.engines.orchestration(), want = ORCH_ID[t.instrument];
    var inst = MD.roll.instrumentOf(t);
    var fold = function (s) { return String(s || '').toLowerCase().replace(/[^a-z0-9]/g, ''); };
    var hit = null;
    o.entries.forEach(function (e) {
      if (hit) return;
      var names = [e.id, e.name].concat(e.aliases ? (Array.isArray(e.aliases) ? e.aliases : Object.values(e.aliases)) : []).map(fold);
      if ((want && names.indexOf(fold(want)) >= 0) || (inst && names.indexOf(fold(inst.name)) >= 0)) hit = e;
    });
    return hit;
  }
  function aboutSection(t) {
    var e = orchEntry(t);
    if (!e) return null;
    return section('About the ' + e.name, [
      U.el('p', { class: 'prose', text: e.summary || '' }),
      U.button('Read More', function () { MD.browser.showEntry(e.id); }, { title: 'Doublings, pairings and what to avoid, with sources' })
    ]);
  }

  function returnSection() {
    var p = app.project();
    var ret = p.returns && p.returns[0];
    if (!ret) return null;
    return section('Reverb Return', ret.audioFx.map(function (dev) { return devicePanel('return', dev); }));
  }

  function render() {
    if (!body || app.view.itab !== 'track') return;
    var focused = document.activeElement && body.contains(document.activeElement) ? document.activeElement.getAttribute('aria-label') : null;
    var scroll = body.scrollTop;
    U.clear(body);
    var t = app.track();
    if (!t) { body.appendChild(U.el('p', { class: 'note-line', text: 'Add a track, or describe some music in the middle.' })); return; }
    if (!MD.engines.isReady()) return;
    var c = app.clip();
    [instrumentSection(t), c ? clipSection(t, c) : null, soundSection(t), chainSection(t, 'midi'), chainSection(t, 'audio'),
     mixSection(t), aboutSection(t), returnSection()].forEach(function (s) { if (s) body.appendChild(s); });
    body.scrollTop = scroll;
    if (focused) { var f = body.querySelector('[aria-label="' + focused.replace(/"/g, '\\"') + '"]'); if (f) f.focus(); }
  }

  var lastKey = null;
  function init() {
    body = document.getElementById('inspector-body');
    app.on(function (w) {
      if (app.view.itab !== 'track') return;
      var t = app.track(), c = app.clip();
      var key = JSON.stringify([app.sel.trackId, app.sel.clipId, t && [t.name, t.instrument, t.sound, t.midiFx, t.audioFx, t.volume, t.pan, t.send],
        c && [c.name, c.length, c.start, c.notes.length, c.source], app.project().returns, Object.keys(openMore).filter(function (k) { return openMore[k]; })]);
      if (key === lastKey && !w.all) return;
      lastKey = key;
      render();
    });
  }

  MD.inspector = { init: init, render: function () { lastKey = null; render(); }, orchEntry: orchEntry };
})(globalThis.MD = globalThis.MD || {});
