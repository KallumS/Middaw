/* The family's Lua, loaded once and spoken to in JavaScript.
 *
 * Every file under web/engines/ is fetched as bytes and run in Middaw's Lua
 * (web/lua/), unchanged. The adapters (Noterator's) are how the generators
 * are spoken to: settings in, notes out, the same protocol Miderator and
 * Noterator use, so Middaw offers each engine exactly what they offer.
 */
(function (MD) {
  'use strict';
  var L = globalThis.MiddawLua;

  var FILES = [
    'good-idea/gi_theory.lua', 'good-idea/gi_idea.lua',
    'midi-catalogue/mc_theory.lua', 'midi-catalogue/mc_orchestra.lua', 'midi-catalogue/mc_catalogue.lua',
    'midi-suggester/ms_theory.lua', 'midi-suggester/ms_read.lua', 'midi-suggester/ms_harmony.lua', 'midi-suggester/ms_melody.lua',
    'midi-variator/mv_theory.lua', 'midi-variator/mv_vary.lua',
    'starting-blocks/sb_engine.lua',
    'adapters/common.lua', 'adapters/index.lua', 'adapters/good_idea.lua', 'adapters/midi_suggester.lua',
    'adapters/midi_variator.lua', 'adapters/starting_blocks.lua', 'adapters/midi_catalogue.lua',
    'notation/sb_notate.lua', 'notation/sb_draw.lua', 'notation/sb_glyphs.lua',
    'battle-pass/bp_theory.lua', 'battle-pass/bp_loot.lua', 'battle-pass/bp_game.lua',
    'orchestration/orchestration_data.lua', 'orchestration/orchestration_composers.lua'
  ];

  var sources = {}, modules = {}, env = null;

  function bytesToString(buf) {
    var u8 = new Uint8Array(buf), out = '', CH = 8192;
    for (var i = 0; i < u8.length; i += CH) out += String.fromCharCode.apply(null, u8.subarray(i, i + CH));
    return out;
  }

  function engine(name) {
    if (modules[name] === undefined) {
      var src = sources[name];
      if (src === undefined) throw new L.LuaError("engine '" + name + "' is not loaded");
      var r = L.first(L.load(src, name, env)());
      modules[name] = r === undefined ? false : r;
    }
    return modules[name];
  }

  // Load every file; resolves when the engines can be called.
  function load(base, fetchFn) {
    base = base || 'engines/';
    fetchFn = fetchFn || function (url) { return fetch(url).then(function (r) {
      if (!r.ok) throw new Error(url + ': ' + r.status);
      return r.arrayBuffer();
    }); };
    return Promise.all(FILES.map(function (f) {
      return fetchFn(base + f).then(function (buf) { sources[f] = typeof buf === 'string' ? buf : bytesToString(buf); });
    })).then(function () {
      env = L.makeEnv({
        print: function (s) { console.log('[lua] ' + L.fromBytes(s)); },
        readFile: function (p) { return MD.store ? MD.store.readLua(p) : null; },
        writeFile: function (p, d) { if (MD.store) MD.store.writeLua(p, d); }
      });
      env.set('engine', function (name) { return engine(name); });
      env.set('dofile', function (name) { return L.first(engine(String(name).replace(/^.*engines\//, ''))); });
      ready = true;
    });
  }
  var ready = false;

  // Call a Lua function with JS arguments; JS result.
  function call(mod, fname) {
    var m = typeof mod === 'string' ? engine(mod) : mod;
    var f = L.index(m, fname);
    var args = [];
    for (var i = 2; i < arguments.length; i++) {
      var a = arguments[i];
      args.push(a instanceof L.LuaTable ? a : L.toLua(a));
    }
    return L.first(L.call(f)(...args));
  }
  function js(v) { return L.toJS(v); }

  // --------------------------------------------------------- generators --
  var adapters = null;
  function generators() {
    if (adapters) return adapters;
    adapters = js(engine('adapters/index.lua')).map(function (path) {
      var A = engine(path);
      return { id: js(L.index(A, 'id')), name: js(L.index(A, 'name')), description: js(L.index(A, 'description')) || '',
               input: js(L.index(A, 'input')), panel: js(L.index(A, 'panel')) || null, A: A, path: path };
    });
    return adapters;
  }
  function gen(id) {
    var list = generators();
    for (var i = 0; i < list.length; i++) if (list[i].id === id) return list[i];
    return null;
  }
  // A generator's settings live in Lua, as the engine left them.
  function Session(id) {
    this.g = gen(id);
    this.st = L.first(L.call(L.index(this.g.A, 'newState'))());
  }
  Session.prototype.useKey = function (key) { call(this.g.A, 'useKey', this.st, key.root, key.scale); };
  Session.prototype.settings = function (ctx) { return js(call(this.g.A, 'settings', this.st, L.toLua(ctx))); };
  Session.prototype.set = function (settingId, index, ctx) { call(this.g.A, 'set', this.st, settingId, index, L.toLua(ctx)); };
  Session.prototype.get = function (field) { return js(L.index(this.st, L.toBytes(field))); };
  Session.prototype.generate = function (ctx, seed, count) {
    var r = js(call(this.g.A, 'generate', this.st, L.toLua(ctx), seed, count || 6));
    if (r && r.results && !Array.isArray(r.results)) r.results = Object.keys(r.results).map(function (k) { return r.results[k]; });
    (r && r.results || []).forEach(function (res) {
      if (res.parts && !Array.isArray(res.parts)) res.parts = Object.keys(res.parts).map(function (k) { return res.parts[k]; });
      (res.parts || []).forEach(function (p) { if (!Array.isArray(p.notes)) p.notes = p.notes ? Object.keys(p.notes).map(function (k) { return p.notes[k]; }) : []; });
    });
    return r || { results: [] };
  };
  Session.prototype.snapshot = function () { return js(this.st); };
  Session.prototype.restore = function (o) {
    var self = this;
    Object.keys(o || {}).forEach(function (k) { L.setindex(self.st, L.toBytes(k), L.toLua(o[k])); });
  };

  // ------------------------------------------------------------- theory --
  // Chord names are ScaleView's, read by Midi Variator's port of it.
  var keyCache = {};
  function luaKey(key) {
    var k = key.root + ':' + key.scale;
    if (!keyCache[k]) {
      // mv_theory knows the seven-note scales; anything else names chords
      // against the parallel major or minor.
      var MV = engine('midi-variator/mv_theory.lua');
      var scaleName = MD.model.SCALE_NAMES[key.scale - 1];
      var map = { 'Major': 1, 'Minor': 2, 'Harmonic Minor': 3, 'Ionian': 1, 'Dorian': 4, 'Phrygian': 5, 'Lydian': 6,
                  'Mixolydian': 7, 'Aeolian': 2, 'Major Pentatonic': 1, 'Minor Pentatonic': 2, 'Major Blues': 1,
                  'Minor Blues': 2, 'Whole Tone': 1, 'Diminished W-H': 2, 'Diminished H-W': 1 };
      keyCache[k] = call(MV, 'key', key.root, map[scaleName] || 1);
    }
    return keyCache[k];
  }
  function nameChord(pitches, key) {
    if (pitches.length < 2) return '';
    var r = L.call(L.index(engine('midi-variator/mv_theory.lua'), 'nameChord'))(L.toLua(pitches), luaKey(key));
    return js(L.first(r)) || '';
  }
  function noteNames(key) {
    var k = js(L.index(luaKey(key), 'names'));
    var out = [];
    for (var pc = 0; pc < 12; pc++) out.push(k[pc] || k[String(pc)] || '');
    return out;
  }
  // Midi Suggester's key finder, which Miderator's key lane uses too.
  function detectKey(notes) {
    if (!notes.length) return null;
    var sorted = notes.slice().sort(function (a, b) { return a.start - b.start; });
    var r = js(call('midi-variator/mv_theory.lua', 'detectKey',
      sorted.map(function (n) { return { pitch: n.pitch, start: n.start, len: n.len }; }),
      sorted[0].pitch % 12, sorted[sorted.length - 1].pitch % 12));
    if (!r || !r.length) return null;
    return { root: r[0].root, scale: r[0].scale === 2 ? 2 : 1 };
  }

  // -------------------------------------------------------- orchestra ----
  // Midi Catalogue's instruments: range, sweet spot, speed, breath, hands.
  // Noterator's instruments beyond the orchestra (Source/Core/Instruments.cpp).
  var EXTRA = [
    { id: 'asax', name: 'Alto Saxophone', family: 'Woodwind', low: 49, high: 80, sweet: [53, 76], poly: 1, fast: 0.09, leap: 12 },
    { id: 'tsax', name: 'Tenor Saxophone', family: 'Woodwind', low: 44, high: 75, sweet: [48, 70], poly: 1, fast: 0.09, leap: 12 },
    { id: 'bsax', name: 'Baritone Saxophone', family: 'Woodwind', low: 36, high: 69, sweet: [40, 62], poly: 1, fast: 0.10, leap: 12 },
    { id: 'vib', name: 'Vibraphone', family: 'Percussion', low: 53, high: 89, sweet: [55, 84], poly: 4, fast: 0.09, leap: 12 },
    { id: 'sop', name: 'Soprano', family: 'Voices', low: 60, high: 81, sweet: [64, 77], poly: 1, fast: 0.15, leap: 9 },
    { id: 'alto', name: 'Alto', family: 'Voices', low: 53, high: 74, sweet: [57, 69], poly: 1, fast: 0.15, leap: 9 },
    { id: 'ten', name: 'Tenor', family: 'Voices', low: 48, high: 69, sweet: [50, 65], poly: 1, fast: 0.15, leap: 9 },
    { id: 'bass', name: 'Bass', family: 'Voices', low: 40, high: 64, sweet: [43, 60], poly: 1, fast: 0.15, leap: 9 },
    { id: 'gtr', name: 'Guitar', family: 'Band', low: 40, high: 83, sweet: [45, 76], poly: 6, fast: 0.08, leap: 12 },
    { id: 'ebass', name: 'Bass Guitar', family: 'Band', low: 28, high: 67, sweet: [28, 55], poly: 1, fast: 0.09, leap: 12 },
    { id: 'ubass', name: 'Upright Bass', family: 'Band', low: 28, high: 67, sweet: [28, 55], poly: 1, fast: 0.10, leap: 12 },
    { id: 'synth', name: 'Synth', family: 'Band', low: 24, high: 108, sweet: [36, 96], poly: 16, fast: 0.03, leap: 48 },
    { id: 'kit', name: 'Drum Kit', family: 'Band', low: 35, high: 81, sweet: [35, 81], poly: 4, fast: 0.05, leap: 127, drums: true }
  ];
  var orchestra = null;
  function instruments() {
    if (orchestra) return orchestra;
    var list = js(L.index(engine('midi-catalogue/mc_orchestra.lua'), 'INSTRUMENTS')) || [];
    orchestra = (Array.isArray(list) ? list : Object.keys(list).map(function (k) { return list[k]; })).concat(EXTRA);
    return orchestra;
  }
  function sections() {
    var list = js(L.index(engine('midi-catalogue/mc_orchestra.lua'), 'SECTIONS')) || [];
    return Array.isArray(list) ? list : Object.keys(list).map(function (k) { return list[k]; });
  }

  // ----------------------------------------------------------- notation --
  var notate = null;
  function notation() {
    if (notate) return notate;
    var N = engine('notation/sb_notate.lua'), D = engine('notation/sb_draw.lua'), G = engine('notation/sb_glyphs.lua');
    L.call(L.index(D, 'setNotate'))(N);
    L.call(L.index(D, 'setGlyphs'))(G);
    notate = { N: N, D: D, E: engine('starting-blocks/sb_engine.lua') };
    return notate;
  }

  // --------------------------------------------------------- the pass ----
  var pass = null;
  function battlePass() {
    if (pass) return pass;
    var T = engine('battle-pass/bp_theory.lua');
    var Lt = L.first(L.call(L.index(engine('battle-pass/bp_loot.lua'), 'init'))(T));
    var G = L.first(L.call(L.index(engine('battle-pass/bp_game.lua'), 'init'))(Lt));
    pass = { G: G, L: Lt, T: T };
    return pass;
  }

  // ----------------------------------------------------- orchestration ---
  var orchEntries = null;
  function orchestration() {
    if (orchEntries) return orchEntries;
    var A = js(engine('orchestration/orchestration_data.lua'));
    var B = js(engine('orchestration/orchestration_composers.lua'));
    var toList = function (x) { return !x ? [] : Array.isArray(x) ? x : Object.keys(x).map(function (k) { return x[k]; }); };
    orchEntries = { entries: toList(A.ENTRIES).concat(toList(B && B.ENTRIES)), sources: Object.assign({}, (B && B.SOURCES) || {}, A.SOURCES || {}) };
    return orchEntries;
  }

  MD.engines = {
    FILES: FILES, load: load, engine: engine, call: call, js: js, isReady: function () { return ready; },
    generators: generators, gen: gen, Session: Session,
    nameChord: nameChord, noteNames: noteNames, detectKey: detectKey, luaKey: luaKey,
    instruments: instruments, sections: sections, notation: notation, battlePass: battlePass, orchestration: orchestration
  };
})(typeof module === 'object' && module.exports
  ? (module.exports = (globalThis.MD = globalThis.MD || {}))
  : (globalThis.MD = globalThis.MD || {}));
