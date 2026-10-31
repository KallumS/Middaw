/* middaw/functional.py: progressions written from chord function. */
(function (C) {
  'use strict';
  var P = globalThis.MiddawPy;

  var MINOR_KEY_MODES = new Set(['minor', 'aeolian', 'harmonic_minor', 'melodic_minor']);
  var TONIC = 'tonic', PREDOMINANT = 'predominant', DOMINANT = 'dominant';
  var DEGREE_FUNCTION = { 0: TONIC, 1: PREDOMINANT, 2: TONIC, 3: PREDOMINANT, 4: DOMINANT, 5: TONIC, 6: DOMINANT };
  var MINOR_QUALITIES = new Set(['min', 'dim', 'min7', 'min7b5', 'dim7', 'min6', 'min9', 'minmaj7', 'minadd9']);
  var QUALITY_SUFFIX = { maj: '', min: '', dim: 'o', aug: '+', maj7: 'maj7', minmaj7: 'maj7', augmaj7: '+maj7', aug7: '+7',
    dom7: '7', min7: '7', min7b5: '0', dim7: 'o7', maj6: '6', min6: '6' };

  function FunctionalChord(symbol, root, fn, label, target, numeral) {
    this.symbol = symbol; this.root = root; this.function = fn; this.label = label || '';
    this.target = target === undefined ? null : target; this.numeral = numeral || '';
  }
  Object.defineProperty(FunctionalChord.prototype, 'display', { get: function () { return this.label || this.symbol; } });

  function first(s) { return s.slice(0, 1); }
  function quality_of(intervals) {
    var want = intervals.slice().sort(function (a, b) { return a - b; }).join(',');
    var names = Object.keys(C.QUALITIES);
    for (var i = 0; i < names.length; i++) {
      if (C.QUALITIES[names[i]].slice().sort(function (a, b) { return a - b; }).join(',') === want) return names[i];
    }
    return 'maj';
  }
  function apply_case(numeral, quality) {
    var acc = '';
    while (numeral && 'b#x'.indexOf(numeral[0]) >= 0) { acc += numeral[0]; numeral = numeral.slice(1); }
    if (MINOR_QUALITIES.has(quality)) numeral = numeral.toLowerCase();
    return acc + numeral + (QUALITY_SUFFIX[quality] !== undefined ? QUALITY_SUFFIX[quality] : '');
  }
  function roman_for(root_interval, quality) { return apply_case(C.ROMAN_BY_INTERVAL[P.mod(root_interval, 12)], quality); }
  function roman_for_scale_degree(degree, interval, quality) { return apply_case(C.roman_for_degree(degree, interval), quality); }

  function diatonic_chords(tonic, mode, sevenths) {
    var parent = C.PARENT_SCALE[mode] || mode;
    var scale = C.scale_pitch_classes(tonic, parent);
    if (scale.length !== 7) scale = C.scale_pitch_classes(tonic, 'major');
    var steps = C.SCALES[parent] || C.SCALES.major;
    if (steps.length !== 7) steps = C.SCALES.major;
    var chords = [], size = sevenths ? 4 : 3;
    for (var degree = 0; degree < 7; degree++) {
      var picks = [];
      for (var st = 0; st < size; st++) picks.push(scale[(degree + 2 * st) % 7]);
      var root = picks[0];
      var intervals = picks.map(function (pc) { return P.mod(pc - root, 12); }).sort(function (a, b) { return a - b; });
      var quality = quality_of(intervals);
      var numeral = roman_for_scale_degree(degree, steps[degree], MINOR_QUALITIES.has(quality) ? 'min' : 'maj');
      chords.push(new FunctionalChord(roman_for_scale_degree(degree, steps[degree], quality), root, DEGREE_FUNCTION[degree], '', null, numeral));
    }
    return chords;
  }
  function target_name(tonic, target_root, mode) {
    var d = diatonic_chords(tonic, mode, false);
    for (var i = 0; i < d.length; i++) if (d[i].root === P.mod(target_root, 12)) return d[i].numeral || d[i].symbol;
    return C.ROMAN_BY_INTERVAL[P.mod(target_root - tonic, 12)];
  }
  function secondary_dominant(tonic, mode, target, kind) {
    kind = kind || 'V7';
    var is_tonic = target.root === tonic;
    var tname = target.numeral || target_name(tonic, target.root, mode);
    var suffix = is_tonic ? '' : '/' + tname;
    var root, quality, kind_name;
    if (kind === 'SubV7') { root = P.mod(target.root + 1, 12); quality = 'dom7'; kind_name = 'SubV7'; }
    else if (kind === 'bVII7') { root = P.mod(target.root + 10, 12); quality = 'dom7'; kind_name = 'bVII7'; }
    else if (kind === 'viio7') { root = P.mod(target.root + 11, 12); quality = 'dim7'; kind_name = 'viio7'; }
    else { root = P.mod(target.root + 7, 12); quality = 'dom7'; kind_name = 'V7'; }
    var symbol = kind === 'V7' ? (is_tonic ? 'V7' : 'V7/' + tname) : roman_for(P.mod(root - tonic, 12), quality);
    return new FunctionalChord(symbol, root, DOMINANT, kind_name + suffix, target.root);
  }
  function byRoot(chords) { var m = new Map(); chords.forEach(function (c) { m.set(c.root, c); }); return m; }
  function related_two(tonic, mode, dominant) {
    var root = P.mod(dominant.root + 7, 12);
    var diatonic = byRoot(diatonic_chords(tonic, mode, true));
    var target = diatonic.get(dominant.target !== null ? dominant.target : tonic);
    var minor_target = target !== undefined && P.islower(first(target.symbol));
    var quality = minor_target ? 'min7b5' : 'min7';
    var suffix = (dominant.target === null || dominant.target === tonic || target === undefined) ? '' : '/' + (target.numeral || target.symbol);
    return new FunctionalChord(roman_for(P.mod(root - tonic, 12), quality), root, PREDOMINANT, 'ii' + suffix, dominant.root);
  }

  var PRECEDING_FUNCTION = {
    tonic: [[DOMINANT, 0.55], [PREDOMINANT, 0.35], [TONIC, 0.10]],
    predominant: [[TONIC, 0.50], [PREDOMINANT, 0.30], [DOMINANT, 0.20]],
    dominant: [[PREDOMINANT, 0.65], [TONIC, 0.35]]
  };
  var DEGREE_WEIGHT = { 0: 6.0, 1: 3.0, 2: 1.2, 3: 4.0, 4: 6.0, 5: 2.5, 6: 0.9 };

  function weighted(rng, options) {
    var total = P.sum(options.map(function (o) { return o[0]; }));
    if (total <= 0) return null;
    var roll = rng.random() * total;
    for (var i = 0; i < options.length; i++) { roll -= options[i][0]; if (roll <= 0) return options[i][1]; }
    return options[options.length - 1][1];
  }
  function closing_chords(tonic, mode, kind, sevenths) {
    var cadence = C.cadence_get(kind);
    if (!cadence) return [];
    var diatonic = diatonic_chords(tonic, mode, sevenths);
    return cadence.degrees.map(function (degree, position) {
      var chord = diatonic[degree];
      if (cadence.seventh && position === 0 && degree === 4 && (MINOR_KEY_MODES.has(mode) || !P.islower(first(chord.symbol)))) {
        chord = new FunctionalChord('V7', chord.root, DOMINANT, 'V7', tonic, 'V');
      }
      return chord;
    });
  }
  function skeleton(rng, tonic, mode, length, sevenths, cadence) {
    var diatonic = diatonic_chords(tonic, mode, sevenths);
    var by_function = { tonic: [], predominant: [], dominant: [] };
    diatonic.forEach(function (chord, degree) { by_function[chord.function].push([DEGREE_WEIGHT[degree], chord]); });
    var progression = closing_chords(tonic, mode, cadence, sevenths);
    if (!progression.length) progression = [diatonic[0]];
    progression = progression.slice(-length);
    var open_at_home = !!cadence && length > progression.length && rng.random() < 0.8;
    if (open_at_home) length -= 1;
    while (progression.length < length) {
      var head = progression[0];
      var wanted = weighted(rng, PRECEDING_FUNCTION[head.function].map(function (fw) { return [fw[1], fw[0]]; }));
      var options = by_function[wanted].filter(function (wc) { return wc[1].root !== head.root; });
      if (progression.length > 1) {
        var recent = progression[1].root;
        options = options.map(function (wc) { return [wc[0] * (wc[1].root === recent ? 0.25 : 1.0), wc[1]]; });
      }
      var chord = weighted(rng, options.length ? options : by_function[wanted]);
      if (chord === null) break;
      progression.unshift(chord);
    }
    if (open_at_home && progression[0].root !== tonic) progression.unshift(diatonic[0]);
    return progression;
  }
  function muddies_the_tonic(chord, tonic, home_is_minor) {
    if (chord.root !== tonic || chord.function === TONIC) return false;
    var is_dom7 = chord.symbol.slice(-1) === '7' && P.isupper(first(chord.symbol));
    return home_is_minor || !is_dom7;
  }
  function chord_at(tonic, mode, root) {
    var d = diatonic_chords(tonic, mode, true);
    for (var i = 0; i < d.length; i++) if (d[i].root === P.mod(root, 12)) return d[i];
    return new FunctionalChord(roman_for(P.mod(root - tonic, 12), 'maj'), P.mod(root, 12), TONIC);
  }
  function decorate(rng, tonic, mode, progression, chromaticism, protect) {
    var out = progression.slice();
    var diatonic = diatonic_chords(tonic, mode, true);
    var home_is_minor = P.islower(first(diatonic[0].symbol));
    var diatonic_symbols = new Map();
    diatonic.forEach(function (c) { diatonic_symbols.set(c.root, c.symbol); });
    var guarded = new Set(protect ? P.range(out.length - protect, out.length) : []);
    function accept(index, chord) {
      if (guarded.has(index) || muddies_the_tonic(chord, tonic, home_is_minor)) return false;
      out[index] = chord;
      return true;
    }
    var index;
    for (index = 1; index < out.length; index++) {
      var target = out[index];
      if (target.root === tonic) continue;
      if (rng.random() > chromaticism * 0.8) continue;
      accept(index - 1, secondary_dominant(tonic, mode, target));
    }
    // Python's enumerate(out) sees the list as it changes
    for (index = 0; index < out.length; index++) {
      var chord = out[index];
      if (chord.function !== DOMINANT || chord.target === null) continue;
      if (rng.random() > chromaticism * 0.45) continue;
      var t = chord_at(tonic, mode, chord.target);
      var kind = weighted(rng, [[3.0, 'SubV7'], [2.0, 'bVII7'], [1.2, 'viio7']]);
      accept(index, secondary_dominant(tonic, mode, t, kind));
    }
    for (index = out.length - 1; index > 0; index--) {
      var ch = out[index];
      if (ch.function !== DOMINANT || ch.label.indexOf('viio7') === 0) continue;
      var previous = out[index - 1];
      if (previous.function === PREDOMINANT && previous.label.indexOf('ii') === 0) continue;
      if (rng.random() > 0.35 + 0.4 * chromaticism) continue;
      var two = related_two(tonic, mode, ch);
      if (diatonic_symbols.get(two.root) !== two.symbol && rng.random() > chromaticism) continue;
      accept(index - 1, two);
    }
    return out;
  }
  function raise_the_leading_tone(rng, tonic, mode, progression) {
    return progression.map(function (chord) {
      var minor_dominant = chord.function === DOMINANT && chord.root === P.mod(tonic + 7, 12) &&
        P.islower(first(chord.symbol)) && MINOR_KEY_MODES.has(mode);
      if (minor_dominant && rng.random() < 0.6) return new FunctionalChord('V7', chord.root, DOMINANT, 'V7', tonic, 'V');
      return chord;
    });
  }
  function generate_progression(o) {
    var tonic = o.tonic, mode = o.mode, rng = o.rng || new globalThis.MiddawPyRandom.Random();
    var length = Math.max(2, Math.min(16, Math.trunc(o.length === undefined ? 4 : o.length)));
    var chromaticism = o.chromaticism === undefined ? 0.2 : o.chromaticism;
    var sevenths = o.sevenths === undefined ? 0.3 : o.sevenths;
    var start_on_tonic = o.start_on_tonic === undefined ? true : o.start_on_tonic;
    var cadence = o.cadence || null;
    var use_sevenths = rng.random() < sevenths;
    var progression = skeleton(rng, tonic, mode, length, use_sevenths, cadence);
    progression = raise_the_leading_tone(rng, tonic, mode, progression);
    var cad = C.cadence_get(cadence);
    var protect = cad ? Math.min(length, cad.degrees.length) : 0;
    progression = decorate(rng, tonic, mode, progression, Math.max(0.0, Math.min(1.0, chromaticism)), protect);
    if (cadence) return progression;
    if (start_on_tonic && progression[0].root !== tonic) {
      for (var i = 0; i < progression.length; i++) {
        if (progression[i].root === tonic && progression[i].function === TONIC) {
          progression = progression.slice(i).concat(progression.slice(0, i));
          break;
        }
      }
    }
    return progression;
  }
  function recadence(symbols, labels, tonic, mode, kind, sevenths) {
    var closing = closing_chords(tonic, mode, kind, !!sevenths);
    if (!closing.length || !symbols.length) return [symbols.slice(), labels.slice()];
    var tail = Math.min(closing.length, symbols.length);
    var end = closing.slice(-tail);
    return [symbols.slice(0, symbols.length - tail).concat(end.map(function (c) { return c.symbol; })),
            labels.slice(0, labels.length - tail).concat(end.map(function (c) { return c.display; }))];
  }

  Object.assign(C, {
    FunctionalChord: FunctionalChord, diatonic_chords: diatonic_chords, roman_for: roman_for, secondary_dominant: secondary_dominant,
    related_two: related_two, closing_chords: closing_chords, generate_progression: generate_progression, recadence: recadence,
    MINOR_KEY_MODES: MINOR_KEY_MODES, TONIC: TONIC, PREDOMINANT: PREDOMINANT, DOMINANT: DOMINANT
  });
})(globalThis.MiddawComposer);
