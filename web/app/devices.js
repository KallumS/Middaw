/* The devices a track can hold, and how Middaw shows each one.
 *
 * Instruments make the sound, MIDI effects work on notes before the
 * instrument, audio effects on the sound after it. The family's JSFX run
 * unchanged (web/devices/); Middaw draws their controls from their own slider
 * lines, grouped here so the controls you reach for come first.
 */
(function (MD) {
  'use strict';

  var DEVICES = {
    synth:    { name: 'Middaw Synth', type: 'instrument', kind: 'synth' },
    kit:      { name: 'Drum Kit', type: 'instrument', kind: 'kit' },
    sampler:  { name: 'Instant Instrument', type: 'instrument', kind: 'sampler', drop: 1 },
    creator:  { name: 'Instrument Creator', type: 'instrument', kind: 'jsfx', file: 'Instrument-Creator.jsfx',
                main: [13, 14, 15, 16, 17, 18, 23], parts: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12], more: [19, 20, 21, 22] },
    shuffler: { name: 'Transient Shuffler', type: 'instrument', kind: 'jsfx', file: 'TransientShuffler.jsfx', drop: 2,
                main: [7, 1, 2, 3], more: [4, 5, 6, 8, 9, 10] },
    autocc:   { name: 'AutoCC', type: 'midi', kind: 'jsfx', file: 'AutoCC.jsfx',
                main: [1, 2, 3, 18], lanes: [11, 12, 13, 14, 15, 16, 17], more: [4, 5, 6, 7, 8, 9, 10, 19] },
    evolver:  { name: 'Midi Evolver', type: 'midi', kind: 'jsfx', file: 'Midi Evolver.jsfx',
                main: [1, 2, 3, 4, 5, 8], layers: [9, 10, 11, 12, 13],
                more: [6, 7, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 14, 15, 16, 17, 18, 29, 30, 31, 32] },
    mpc:      { name: 'MIDI Production Center', type: 'midi', kind: 'jsfx', file: 'MIDI_Production_Center.jsfx',
                imports: ['mpc_core.jsfx-inc', 'mpc_engine.jsfx-inc', 'mpc_ui.jsfx-inc'], pads: true,
                main: [1, 2, 3, 4, 5], fx: [[12, 13, 14, 15, 16, 17], [18, 19, 20, 21, 22, 23, 24, 25], [26, 27, 28, 29, 30],
                                          [31, 32, 33, 34, 35, 36], [37, 38, 39, 40, 41, 42, 43], [44, 45, 46, 47]],
                more: [6, 7, 8, 9, 10, 11] },
    reverberator: { name: 'Reverberator', type: 'audio', kind: 'jsfx', file: 'Reverberator.jsfx',
                main: [1, 2, 3, 4, 5, 8], more: [6, 7, 9, 10, 11, 12] }
  };

  var sources = {}, headers = {};

  function load(base) {
    base = base || 'devices/';
    var files = {};
    Object.keys(DEVICES).forEach(function (id) {
      var d = DEVICES[id];
      if (d.file) files[d.file] = true;
      (d.imports || []).forEach(function (f) { files[f] = true; });
    });
    return Promise.all(Object.keys(files).map(function (f) {
      return fetch(base + encodeURIComponent(f)).then(function (r) { return r.text(); }).then(function (t) { sources[f] = t; });
    })).then(function () {
      Object.keys(DEVICES).forEach(function (id) {
        var d = DEVICES[id];
        if (d.kind !== 'jsfx') return;
        headers[id] = globalThis.MiddawJSFX.parseFile(sources[d.file], function (n) { return sources[n]; });
      });
      var ic = sources['Instrument-Creator.jsfx'];
      if (ic) DEVICES.creator.presets = creatorPresets(ic);
    });
  }

  // Instrument Creator's nineteen instruments, read from its own table.
  function creatorPresets(src) {
    var at = src.indexOf('function preset_name'), body = src.slice(at, src.indexOf(');', at));
    var names = [], m, re = /k==(\d+)\?"([^"]+)"/g;
    while ((m = re.exec(body)) !== null) names[Number(m[1])] = m[2];
    var last = /:"([^"]+)";\s*$/.exec(body);
    if (last) names.push(last[1]);
    var rows = [], r2 = /^pdef\(\s*(\d+),([^)]*)\);/gm;
    while ((m = r2.exec(src)) !== null) rows[Number(m[1])] = m[2].split(',').map(function (x) { return Number(x.trim()); });
    return names.map(function (n, i) { return { name: n, values: rows[i] || [] }; });
  }

  function sliders(id) { return headers[id] ? headers[id].sliders : []; }
  function slider(id, n) {
    var list = sliders(id);
    for (var i = 0; i < list.length; i++) if (list[i].index === n) return list[i];
    return null;
  }

  // What the audio thread needs to build a device.
  function spec(dev) {
    var d = DEVICES[dev.device];
    if (!d) return null;
    var s = { id: dev.id, device: dev.device, kind: d.kind };
    if (d.kind === 'jsfx') {
      s.source = sources[d.file];
      s.sourceKey = d.file;
      s.imports = {};
      (d.imports || []).forEach(function (f) { s.imports[f] = sources[f]; });
      s.sliders = dev.sliders || {};
      s.state = dev.state || null;
    }
    if (d.kind === 'synth') s.preset = dev.preset || 'keys';
    if (d.kind === 'sampler' && dev.sample) s.sample = dev.sample;
    return s;
  }

  function make(device, extra) {
    var o = { id: MD.model.uid('d'), device: device, sliders: {}, state: null };
    if (extra) Object.keys(extra).forEach(function (k) { o[k] = extra[k]; });
    return o;
  }

  // Which of Middaw's own presets suits each instrument of the orchestra.
  var PRESET_FOR = {
    vln1: 'solo', vln2: 'strings', vla: 'strings', vc: 'strings', cb: 'strings',
    picc: 'flute', fl: 'flute', ob: 'reed', eh: 'reed', cl: 'reed', bcl: 'reed', bsn: 'reed', cbsn: 'reed',
    hn: 'brass', tpt: 'brass', tbn: 'brass', btbn: 'brass', tba: 'brass',
    timp: 'timpani', glock: 'bell', xyl: 'mallet', mar: 'mallet', harp: 'harp', cel: 'bell', pno: 'piano',
    asax: 'reed', tsax: 'reed', bsax: 'reed', vib: 'bell', sop: 'choir', alto: 'choir', ten: 'choir', bass: 'choir',
    gtr: 'pluck', ebass: 'bass', ubass: 'bass', synth: 'lead'
  };

  MD.devices = {
    DEVICES: DEVICES, load: load, sliders: sliders, slider: slider, spec: spec, make: make,
    source: function (f) { return sources[f]; }, header: function (id) { return headers[id]; },
    PRESET_FOR: PRESET_FOR
  };
})(typeof module === 'object' && module.exports
  ? (module.exports = (globalThis.MD = globalThis.MD || {}))
  : (globalThis.MD = globalThis.MD || {}));
