/* The composer's foundations, ported line for line from middaw/: scaleview.py,
 * theory.py, chance.py, parts.py, rhythm.py, cadence.py, form.py and
 * vocab.py. Names follow the Python so the two can be read side by side; the
 * Python is the authority and tests/test_composer_js.py holds this to it. */
(function (C) {
  'use strict';
  var P = globalThis.MiddawPy;

  // =============================================================== scaleview
  var SHARP_NAMES = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
  var FLAT_NAMES = ['C', 'Db', 'D', 'Eb', 'E', 'F', 'Gb', 'G', 'Ab', 'A', 'Bb', 'B'];
  var LETTERS = ['C', 'D', 'E', 'F', 'G', 'A', 'B'];
  var LETTER_PCS = [0, 2, 4, 5, 7, 9, 11];
  var ACCIDENTALS = { '-2': 'bb', '-1': 'b', '0': '', '1': '#', '2': 'x' };

  function Root(name, letter, acc) { this.name = name; this.letter = letter; this.acc = acc; }
  Object.defineProperty(Root.prototype, 'pitch_class', { get: function () { return P.mod(LETTER_PCS[this.letter] + this.acc, 12); } });
  var ROOTS = [['C', 0, 0], ['C#', 0, 1], ['Db', 1, -1], ['D', 1, 0], ['D#', 1, 1], ['Eb', 2, -1], ['E', 2, 0], ['F', 3, 0],
    ['F#', 3, 1], ['Gb', 4, -1], ['G', 4, 0], ['G#', 4, 1], ['Ab', 5, -1], ['A', 5, 0], ['A#', 5, 1], ['Bb', 6, -1],
    ['B', 6, 0], ['Cb', 0, -1]].map(function (r) { return new Root(r[0], r[1], r[2]); });
  var ROOTS_BY_NAME = {};
  ROOTS.forEach(function (r) { ROOTS_BY_NAME[r.name] = r; });
  var CHORD_ROOT_NAMES = new Set(ROOTS.map(function (r) { return r.name; }));

  function Scale(name, intervals, letters) { this.name = name; this.intervals = intervals; this.letters = letters; }
  var SV_SCALES = {
    major: new Scale('Major', [0, 2, 4, 5, 7, 9, 11], [0, 1, 2, 3, 4, 5, 6]),
    minor: new Scale('Minor (Natural)', [0, 2, 3, 5, 7, 8, 10], [0, 1, 2, 3, 4, 5, 6]),
    harmonic_minor: new Scale('Harmonic Minor', [0, 2, 3, 5, 7, 8, 11], [0, 1, 2, 3, 4, 5, 6]),
    melodic_minor: new Scale('Melodic Minor', [0, 2, 3, 5, 7, 9, 11], [0, 1, 2, 3, 4, 5, 6]),
    ionian: new Scale('Ionian', [0, 2, 4, 5, 7, 9, 11], [0, 1, 2, 3, 4, 5, 6]),
    dorian: new Scale('Dorian', [0, 2, 3, 5, 7, 9, 10], [0, 1, 2, 3, 4, 5, 6]),
    phrygian: new Scale('Phrygian', [0, 1, 3, 5, 7, 8, 10], [0, 1, 2, 3, 4, 5, 6]),
    lydian: new Scale('Lydian', [0, 2, 4, 6, 7, 9, 11], [0, 1, 2, 3, 4, 5, 6]),
    mixolydian: new Scale('Mixolydian', [0, 2, 4, 5, 7, 9, 10], [0, 1, 2, 3, 4, 5, 6]),
    aeolian: new Scale('Aeolian', [0, 2, 3, 5, 7, 8, 10], [0, 1, 2, 3, 4, 5, 6]),
    locrian: new Scale('Locrian', [0, 1, 3, 5, 6, 8, 10], [0, 1, 2, 3, 4, 5, 6]),
    major_pentatonic: new Scale('Major Pentatonic', [0, 2, 4, 7, 9], [0, 1, 2, 4, 5]),
    minor_pentatonic: new Scale('Minor Pentatonic', [0, 3, 5, 7, 10], [0, 2, 3, 4, 6]),
    major_blues: new Scale('Major Blues', [0, 2, 3, 4, 7, 9], [0, 1, 2, 2, 4, 5]),
    blues: new Scale('Minor Blues', [0, 3, 5, 6, 7, 10], [0, 2, 3, 4, 4, 6]),
    whole_tone: new Scale('Whole Tone', [0, 2, 4, 6, 8, 10], [0, 1, 2, 3, 4, 5]),
    diminished_wh: new Scale('Diminished Whole-Half', [0, 2, 3, 5, 6, 8, 9, 11], [0, 1, 2, 3, 4, 5, 5, 6]),
    diminished_hw: new Scale('Diminished Half-Whole', [0, 1, 3, 4, 6, 7, 9, 10], [0, 1, 2, 2, 3, 4, 5, 6])
  };

  function spell_as(letter, pc) {
    letter = P.mod(letter, 7);
    var offset = P.mod(pc - LETTER_PCS[letter] + 6, 12) - 6;
    var acc = ACCIDENTALS[String(offset)];
    if (acc === undefined) return null;
    return LETTERS[letter] + acc;
  }

  function Key(root, scale) {
    this.root = typeof root === 'string' ? ROOTS_BY_NAME[root] : root;
    this.scale_id = SV_SCALES[scale] ? scale : 'major';
    this.scale = SV_SCALES[this.scale_id];
    this.tonic = this.root.pitch_class;
    this.names = new Map();
    this.active = new Set();
    var sharps = 0, flats = 0, self = this;
    this.scale.intervals.forEach(function (interval, degree) {
      var pc = P.mod(self.tonic + interval, 12);
      var name = spell_as(self.root.letter + self.scale.letters[degree], pc);
      self.active.add(pc);
      if (name) {
        self.names.set(pc, name);
        if (name.indexOf('#') >= 0 || name.indexOf('x') >= 0) sharps++;
        if (name.slice(1).indexOf('b') >= 0) flats++;
      }
    });
    this.uses_flats = flats > sharps;
    var outside = this.uses_flats ? FLAT_NAMES : SHARP_NAMES;
    for (var pc = 0; pc < 12; pc++) if (!this.names.has(pc)) this.names.set(pc, outside[pc]);
  }
  Object.defineProperty(Key.prototype, 'label', { get: function () { return this.root.name + ' ' + this.scale.name; } });
  Key.prototype.note_name = function (pc) { return this.names.get(P.mod(pc, 12)); };
  Key.prototype.chord_note_name = function (pc) {
    var name = this.note_name(pc);
    if (CHORD_ROOT_NAMES.has(name)) return name;
    return (this.uses_flats ? FLAT_NAMES : SHARP_NAMES)[P.mod(pc, 12)];
  };

  var CONVENTIONAL_MAJOR = ['C', 'Db', 'D', 'Eb', 'E', 'F', 'F#', 'G', 'Ab', 'A', 'Bb', 'B'];
  var CONVENTIONAL_MINOR = ['C', 'C#', 'D', 'Eb', 'E', 'F', 'F#', 'G', 'G#', 'A', 'Bb', 'B'];
  var MINORISH = ['minor', 'aeolian', 'harmonic_minor', 'melodic_minor', 'dorian', 'phrygian', 'locrian',
    'minor_pentatonic', 'blues', 'diminished_wh'];
  function accidental_load(key) {
    var s = 0;
    key.active.forEach(function (pc) { s += key.names.get(pc).length - 1; });
    return s;
  }
  function key_for(tonic, mode, spelling) {
    if (spelling && ROOTS_BY_NAME[spelling]) return new Key(spelling, mode);
    var preferred = (MINORISH.indexOf(mode) >= 0 ? CONVENTIONAL_MINOR : CONVENTIONAL_MAJOR)[P.mod(tonic, 12)];
    var best = null;
    ROOTS.forEach(function (root) {
      if (root.pitch_class !== P.mod(tonic, 12) || root.name === 'Cb') return;
      var cand = new Key(root, mode);
      if (cand.names.size < 12) return;
      if (best === null) { best = cand; return; }
      if (P.cmp([accidental_load(cand), cand.root.name !== preferred], [accidental_load(best), best.root.name !== preferred]) < 0) best = cand;
    });
    return best || new Key(SHARP_NAMES[P.mod(tonic, 12)], mode);
  }

  // ---------------------------------------------------------- chord reader
  var CORE_RANK = {
    'maj/P/none': 1, 'min/P/none': 2, 'maj/P/b7': 3, 'min/P/b7': 4, 'maj/P/maj7': 5,
    'min/b/b7': 6, 'min/b/bb7': 7, 'min/b/none': 8, 'maj/#/none': 9, 'sus4/P/none': 10, 'sus2/P/none': 11,
    'min/P/maj7': 12, 'maj/#/b7': 13, 'maj/b/b7': 14, 'maj/#/maj7': 15, 'maj/b/maj7': 16,
    'sus4/P/b7': 17, 'sus2/P/b7': 18, 'sus4/P/maj7': 19, 'sus2/P/maj7': 20,
    'none/P/b7': 30, 'none/P/maj7': 31, 'none/P/none': 34, 'none/b/maj7': 41, 'none/b/b7': 42
  };
  var RANK_UNNAMED = { maj: 25, min: 25, sus4: 70, sus2: 70, none: 90 };
  var RANK_TWICE_ODD = 12, RANK_NO_FIFTH = 20, RANK_NO_FIFTH7 = 4, RANK_ELEVENTH = 6, COST_INVERSION = 14;
  var COST_NATURAL = 1, COST_ADD = 2, COST_CLASH = 6, COST_ALTERED = 5, COST_CLASHING = 18, COST_SUS_EXTRA = 12, COST_SIXTH = 4;
  var COST_MIN_SIXTH = 5;
  var SPECIAL = {
    'min/b/none': 'dim', 'min/b/bb7': 'dim7', 'min/b/b7': 'min7b5', 'maj/#/none': 'aug', 'maj/#/b7': 'aug7',
    'maj/#/maj7': 'maj7#5', 'maj/b/b7': '7b5', 'min/P/maj7': 'minMaj7', 'min/none/maj7': 'minMaj7'
  };
  var EXTENSION = { 1: ['b9', true, null], 2: ['9', false, 9], 3: ['#9', true, null], 5: ['11', false, 11], 6: ['#11', true, null], 8: ['b13', true, null] };
  var ASSUMED_KEY = new Set([0, 2, 4, 5, 7, 9, 11]);
  var ASSUMED_TONIC = new Set([0, 4, 7]);

  function core(has, prefer_sharp_five) {
    var used = new Set([0]), third, fifth, seventh;
    if (has.has(4)) { third = 'maj'; used.add(4); }
    else if (has.has(3)) { third = 'min'; used.add(3); }
    else if (has.has(5)) { third = 'sus4'; used.add(5); }
    else if (has.has(2)) { third = 'sus2'; used.add(2); }
    else third = 'none';
    if (has.has(7)) { fifth = 'P'; used.add(7); }
    else if (has.has(6) && has.has(8) && prefer_sharp_five) { fifth = '#'; used.add(8); }
    else if (has.has(6)) { fifth = 'b'; used.add(6); }
    else if (has.has(8)) { fifth = '#'; used.add(8); }
    else fifth = 'none';
    if (has.has(10)) { seventh = 'b7'; used.add(10); }
    else if (has.has(11)) { seventh = 'maj7'; used.add(11); }
    else if (third === 'min' && fifth === 'b' && has.has(9)) { seventh = 'bb7'; used.add(9); }
    else seventh = 'none';
    return [third, fifth, seventh, used];
  }
  function core_name(third, fifth, seventh) {
    var special = SPECIAL[third + '/' + fifth + '/' + seventh];
    if (special) return special;
    var base = third === 'min' ? 'min' : (third === 'sus4' ? 'sus4' : (third === 'sus2' ? 'sus2' : ''));
    var sev = seventh === 'b7' ? '7' : seventh === 'bb7' ? 'dim7' : seventh === 'maj7' ? (third === 'min' ? 'Maj7' : 'maj7') : '';
    var alt = fifth === 'b' ? 'b5' : (fifth === '#' ? '#5' : '');
    var name = (third === 'sus4' || third === 'sus2') ? sev + base : base + sev;
    name += alt;
    if (name === alt && alt) name = '(' + alt + ')';
    return name;
  }
  function rank_of(third, fifth, seventh) {
    var rank;
    if (fifth === 'none') {
      rank = CORE_RANK[third + '/P/' + seventh];
      if (rank === undefined) rank = RANK_UNNAMED[third];
      return rank + (seventh === 'none' ? RANK_NO_FIFTH : RANK_NO_FIFTH7);
    }
    rank = CORE_RANK[third + '/' + fifth + '/' + seventh];
    if (rank !== undefined) return rank;
    return RANK_UNNAMED[third] + (seventh !== 'none' ? RANK_TWICE_ODD : 0);
  }
  function analyse_as(has, root, bass, prefer_sharp_five) {
    var c = core(has, prefer_sharp_five), third = c[0], fifth = c[1], seventh = c[2], used = c[3];
    var rank = rank_of(third, fifth, seventh);
    var name = core_name(third, fifth, seventh), cost = rank;
    var naturals = {}, altered = [], sixth = false, as_eleventh = false;
    for (var interval = 1; interval < 12; interval++) {
      if (!has.has(interval) || used.has(interval)) continue;
      if (interval === 9) { if (seventh === 'none') sixth = true; else naturals[13] = true; continue; }
      var ext = EXTENSION[interval];
      if (ext && ext[1]) altered.push(ext[0]);
      else if (ext) naturals[ext[2]] = true;
      else altered.push('maj7');
    }
    var d, k;
    if (seventh !== 'none' && seventh !== 'bb7') {
      var ninth = !!naturals[9] || altered.some(function (t) { return t === 'b9' || t === '#9'; });
      var number = null;
      if (ninth && naturals[13]) number = 13;
      else if (ninth && naturals[11] && third !== 'maj') number = 11;
      else if (naturals[9]) number = 9;
      if (third === 'sus4' && seventh === 'b7' && naturals[9] && (fifth === 'P' || fifth === 'none')) {
        name = '11'; number = 11; as_eleventh = true;
        naturals[11] = true;
        cost = RANK_ELEVENTH + (fifth === 'none' ? RANK_NO_FIFTH7 : 0);
      } else if (number) {
        name = name.replace('7', String(number));
      }
      var spare = [];
      [9, 11, 13].forEach(function (degree) {
        if (!naturals[degree]) return;
        var implied = number !== null && degree <= number && !(degree === 11 && third === 'maj');
        if (implied) cost += COST_NATURAL;
        else { cost += (degree === 11 && third === 'maj') ? COST_CLASH : COST_ADD; spare.push(degree); }
      });
      if (spare.length) name += '(' + spare.join(',') + ')';
    } else {
      if (sixth) {
        cost += (third === 'min' && fifth === 'P') ? COST_MIN_SIXTH : COST_SIXTH;
        var mark = fifth === 'b' ? 'b5' : (fifth === '#' ? '#5' : '');
        if (naturals[9] && (third === 'maj' || third === 'min')) {
          delete naturals[9];
          name = (third === 'min' ? 'min6/9' : '6/9') + mark;
          cost += COST_ADD;
        } else if (third === 'min') name = 'min6' + mark;
        else if (third === 'maj') name = fifth === '#' ? 'aug6' : ('6' + mark);
        else if (third === 'none') name = '6' + mark;
        else name += '(add6)';
      }
      if (seventh === 'bb7' && naturals[9]) {
        delete naturals[9];
        name = name.replace('dim7', 'dim9');
        cost += COST_ADD;
      }
      [9, 11, 13].forEach(function (degree) {
        if (naturals[degree]) {
          cost += (degree === 11 && third === 'maj') ? COST_CLASH : COST_ADD;
          name += (name === '' ? 'add' : 'Add') + String(degree);
        }
      });
    }
    var dominant = third === 'maj' && seventh === 'b7';
    var triad = (third === 'maj' || third === 'min') && fifth === 'P';
    altered.forEach(function (token) {
      var plain_fifth = fifth !== 'b' && fifth !== '#';
      var at_home = token !== 'maj7' && ((dominant && (plain_fifth || root === bass)) ||
        (plain_fifth && (token === '#11' || (triad && token !== 'b13'))));
      var shown = (token === 'b13' && seventh === 'none') ? 'b6' : (token === 'maj7' ? '(maj7)' : token);
      cost += at_home ? COST_ALTERED : COST_CLASHING;
      name += ((name === '' && seventh === 'none') ? 'add' : '') + shown;
    });
    if ((third === 'sus4' || third === 'sus2') && !as_eleventh) {
      var carried = altered.length + [9, 11, 13].filter(function (x) { return naturals[x]; }).length;
      carried += sixth ? 1 : 0;
      cost += carried * COST_SUS_EXTRA;
    }
    if (third === 'none') name = name === '' ? '5' : name + '(no3)';
    if (root !== bass) cost += COST_INVERSION;
    return [name, cost, rank];
  }
  function analyse(has, root, bass) {
    var a = analyse_as(has, root, bass, false);
    if (has.has(6) && has.has(8) && !has.has(7)) {
      var alt = analyse_as(has, root, bass, true);
      if (alt[1] < a[1]) return alt;
    }
    return a;
  }
  function tonic_degrees(key) {
    var intervals = key.scale.intervals;
    return new Set([0, 2, 4].filter(function (d) { return d < intervals.length; })
      .map(function (d) { return P.mod(key.tonic + intervals[d], 12); }));
  }
  function read_as_root_position(root, bass, voices, key) {
    if (root === bass) return true;
    if ((voices[root] || 0) < 2) return false;
    return tonic_degrees(key).has(root);
  }
  // Starting Blocks' chords decide which roots a chord can have: from
  // sb_engine.lua at fc4dd32, by way of ScaleView Pro df4ea43.
  var BLOCKS_CHORDS = [
    [0, 4, 7], [0, 3, 7], [0, 3, 6], [0, 4, 8], [0, 4, 6], [0, 7],
    [0, 4, 7, 9], [0, 3, 7, 9], [0, 4, 7, 9, 14], [0, 3, 7, 9, 14], [0, 4, 7, 10], [0, 4, 7, 11],
    [0, 3, 7, 10], [0, 3, 7, 11], [0, 3, 6, 10], [0, 3, 6, 9], [0, 4, 8, 10], [0, 4, 8, 11],
    [0, 4, 6, 10], [0, 3, 6, 11], [0, 4, 7, 9, 10],
    [0, 4, 7, 10, 14], [0, 4, 7, 11, 14], [0, 3, 7, 10, 14], [0, 3, 7, 11, 14], [0, 4, 7, 10, 14, 17],
    [0, 4, 7, 11, 14, 17], [0, 3, 7, 10, 14, 17], [0, 4, 7, 10, 14, 17, 21], [0, 4, 7, 11, 14, 17, 21],
    [0, 3, 7, 10, 14, 17, 21],
    [0, 4, 7, 10, 13], [0, 4, 7, 10, 15], [0, 4, 7, 10, 18], [0, 4, 7, 10, 20], [0, 4, 8, 10, 13],
    [0, 4, 8, 10, 15], [0, 4, 6, 10, 13], [0, 4, 8, 10, 13, 15], [0, 4, 7, 10, 13, 21],
    [0, 4, 7, 11, 18], [0, 3, 6, 10, 14], [0, 4, 8, 10, 14], [0, 4, 6, 10, 14], [0, 4, 7, 10, 14, 18],
    [0, 4, 8, 11, 18], [0, 4, 6, 10, 13, 21],
    [0, 2, 7], [0, 5, 7], [0, 5, 7, 10], [0, 5, 7, 10, 14], [0, 5, 7, 11], [0, 4, 7, 14],
    [0, 3, 7, 14], [0, 4, 5, 7], [0, 4, 7, 17], [0, 4, 7, 21], [0, 2, 4, 7], [0, 2, 3, 7],
    [0, 5, 10], [0, 5, 10, 15], [0, 7, 14], [0, 2, 4], [0, 1, 2], [0, 2, 4, 5],
    [0, 6, 10, 16, 21, 26], [0, 4, 6, 7, 10, 13], [0, 6, 10, 15], [0, 5, 10, 15, 19], [0, 5, 6, 7],
    [0, 1, 6], [0, 6, 7], [0, 1, 4, 5, 8, 9], [0, 7, 9, 13, 16], [0, 8, 11, 16, 21], [0, 4, 10],
    [0, 4, 6, 10], [0, 4, 7, 10]
  ];
  var BLOCKS_DIATONIC = [
    [0, 2, 4], [0, 2, 4, 6], [0, 2, 4, 6, 8], [0, 2, 4, 6, 8, 10], [0, 2, 4, 6, 8, 10, 12],
    [0, 2, 4, 5], [0, 1, 4], [0, 3, 4], [0, 4]
  ];
  function mask_from(classes, root) {
    var mask = 0;
    classes.forEach(function (pc) { mask |= 1 << P.mod(pc - root, 12); });
    return mask;
  }
  var BLOCKS_TYPES = new Set(BLOCKS_CHORDS.map(function (shape) { return mask_from(shape, 0); }));
  var KEY_CHORDS = new Map();
  function blocks_key_chords(key) {
    var cache_key = key.tonic + '/' + key.scale_id;
    var chords = KEY_CHORDS.get(cache_key);
    if (chords === undefined) {
      var intervals = key.scale.intervals, n = intervals.length;
      var pitch = function (degree) { return key.tonic + intervals[P.mod(degree, n)] + 12 * P.floordiv(degree, n); };
      chords = new Map();
      for (var degree = 0; degree < n; degree++) {
        var root = P.mod(pitch(degree), 12);
        BLOCKS_DIATONIC.forEach(function (offsets) {
          var mask = 0;
          offsets.forEach(function (o) { mask |= 1 << P.mod(pitch(degree + o), 12); });
          if (!chords.has(mask)) chords.set(mask, new Set());
          chords.get(mask).add(root);
        });
      }
      KEY_CHORDS.set(cache_key, chords);
    }
    return chords;
  }
  function blocks_roots(classes, key) {
    var in_key = blocks_key_chords(key).get(mask_from(classes, 0)) || new Set();
    var roots = new Set();
    for (var root = 0; root < 12; root++) {
      if (classes.has(root) && (in_key.has(root) || BLOCKS_TYPES.has(mask_from(classes, root)))) roots.add(root);
    }
    return roots.size ? roots : null;
  }
  function detect_chord(pitch_classes, bass, key) {
    var notes = new Set(Array.from(pitch_classes, function (n) { return P.int(n); }));
    var classes = new Set(Array.from(notes, function (n) { return P.mod(n, 12); }));
    if (!classes.size) return null;
    var voices = {};
    notes.forEach(function (n) { var pc = P.mod(n, 12); voices[pc] = (voices[pc] || 0) + 1; });
    if (bass === undefined || bass === null) bass = Math.min.apply(null, Array.from(notes));
    bass = P.mod(bass, 12);
    key = key || new Key('C', 'major');
    var name_of = function (pc) { return key.chord_note_name(pc); };
    var in_key = key ? key.active : ASSUMED_KEY;
    var count = classes.size;
    var written = function (root, quality) {
      var name = name_of(root) + quality;
      if (!read_as_root_position(root, bass, voices, key)) name += '/' + name_of(bass);
      return name;
    };
    var fit_of = function (root) {
      return (in_key.has(root) ? 100 : 0) + Array.from(classes).filter(function (pc) { return in_key.has(pc); }).length;
    };
    var better = function (cost, fit, slash, rank, best) {
      return best === null || cost < best[0] || (cost === best[0] && fit > best[1]) ||
        (cost === best[0] && fit === best[1] && best[2] && !slash) ||
        (cost === best[0] && fit === best[1] && slash === best[2] && rank < best[3]);
    };
    if (count === 1) return name_of(bass);
    var root, has, a, fit, slash;
    var blocks = blocks_roots(classes, key);
    if (blocks) {
      var pick = null;
      for (root = 0; root < 12; root++) {
        if (!blocks.has(root)) continue;
        has = new Set(Array.from(classes, function (pc) { return P.mod(pc - root, 12); }));
        a = analyse(has, root, bass);
        var quality = a[0];
        if (count === 2) quality = has.has(7) ? '5' : has.has(4) ? 'maj(no5)' : has.has(3) ? 'min(no5)' : quality;
        fit = fit_of(root); slash = root !== bass;
        if (better(a[1], fit, slash, a[2], pick)) pick = [a[1], fit, slash, a[2], root, quality];
      }
      return written(pick[4], pick[5]);
    }
    var spell_out = function () { return P.range(12).filter(function (pc) { return classes.has(pc); }).map(name_of).join(' '); };
    if (count === 2) {
      for (root = 0; root < 12; root++) {
        if (classes.has(root) && classes.has(P.mod(root + 7, 12))) return written(root, '5');
      }
      for (root = 0; root < 12; root++) {
        if (!classes.has(root)) continue;
        var q = classes.has(P.mod(root + 4, 12)) ? 'maj' : classes.has(P.mod(root + 3, 12)) ? 'min' : null;
        if (q) return written(root, q + '(no5)');
      }
      return spell_out();
    }
    if (count > 7) return spell_out();
    var best = null;
    Array.from(classes).sort(function (x, y) { return x - y; }).forEach(function (r) {
      var h = new Set(Array.from(classes, function (pc) { return P.mod(pc - r, 12); }));
      var b = analyse(h, r, bass);
      var f = fit_of(r), sl = r !== bass;
      if (better(b[1], f, sl, b[2], best)) best = [b[1], f, sl, b[2], r, b[0]];
    });
    return written(best[4], best[5]);
  }

  // ================================================================== theory
  var PITCH_CLASSES = { C: 0, 'C#': 1, DB: 1, D: 2, 'D#': 3, EB: 3, E: 4, FB: 4, 'E#': 5, F: 5, 'F#': 6, GB: 6, G: 7,
    'G#': 8, AB: 8, A: 9, 'A#': 10, BB: 10, B: 11, CB: 11 };
  var NOTE_NAMES = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
  var SCALES = {};
  Object.keys(SV_SCALES).forEach(function (m) { SCALES[m] = SV_SCALES[m].intervals; });
  var PARENT_SCALE = { major_pentatonic: 'major', minor_pentatonic: 'minor', blues: 'minor', major_blues: 'major' };
  var MINOR_MODES = new Set(['minor', 'aeolian', 'harmonic_minor', 'melodic_minor', 'dorian', 'phrygian', 'locrian',
    'minor_pentatonic', 'blues', 'diminished_wh']);
  var BLUES_MODES = new Set(['blues', 'major_blues']);
  var QUALITIES = {
    maj: [0, 4, 7], min: [0, 3, 7], dim: [0, 3, 6], aug: [0, 4, 8], sus2: [0, 2, 7], sus4: [0, 5, 7],
    maj7: [0, 4, 7, 11], min7: [0, 3, 7, 10], dom7: [0, 4, 7, 10], min7b5: [0, 3, 6, 10], dim7: [0, 3, 6, 9],
    maj6: [0, 4, 7, 9], min6: [0, 3, 7, 9], maj9: [0, 4, 7, 11, 14], min9: [0, 3, 7, 10, 14], dom9: [0, 4, 7, 10, 14],
    add9: [0, 4, 7, 14], minadd9: [0, 3, 7, 14], minmaj7: [0, 3, 7, 11], augmaj7: [0, 4, 8, 11], aug7: [0, 4, 8, 10]
  };
  function all(q) { return { maj: q, min: q, dim: q, aug: q }; }
  var SUFFIX_MAP = {
    '': { maj: 'maj', min: 'min', dim: 'dim', aug: 'aug' },
    '7': { maj: 'dom7', min: 'min7', dim: 'min7b5', aug: 'dom7' },
    maj7: { maj: 'maj7', min: 'minmaj7', dim: 'minmaj7', aug: 'augmaj7' },
    '+maj7': all('augmaj7'), '+7': all('aug7'),
    m7: { maj: 'min7', min: 'min7', dim: 'min7b5', aug: 'min7' },
    '6': { maj: 'maj6', min: 'min6', dim: 'min6', aug: 'maj6' },
    '9': { maj: 'dom9', min: 'min9', dim: 'min9', aug: 'dom9' },
    maj9: all('maj9'),
    add9: { maj: 'add9', min: 'minadd9', dim: 'minadd9', aug: 'add9' },
    sus2: all('sus2'), sus4: all('sus4'), o: all('dim'), o7: all('dim7'), '0': all('min7b5'), '+': all('aug')
  };
  var DEGREE_VALUES = { I: 0, II: 1, III: 2, IV: 3, V: 4, VI: 5, VII: 6 };
  var ROMAN_BY_INTERVAL = { 0: 'I', 1: 'bII', 2: 'II', 3: 'bIII', 4: 'III', 5: 'IV', 6: 'bV', 7: 'V', 8: 'bVI', 9: 'VI', 10: 'bVII', 11: 'VII' };
  var PLAIN_NUMERALS = ['I', 'II', 'III', 'IV', 'V', 'VI', 'VII'];
  var MAJOR_INTERVALS = [0, 2, 4, 5, 7, 9, 11];

  function roman_for_degree(degree, interval) {
    degree = P.mod(degree, 7);
    var delta = P.mod(interval - MAJOR_INTERVALS[degree], 12);
    if (delta > 6) delta -= 12;
    var acc = { '-2': 'bb', '-1': 'b', '0': '', '1': '#', '2': 'x' }[String(delta)];
    if (acc === undefined) return ROMAN_BY_INTERVAL[P.mod(interval, 12)];
    return acc + PLAIN_NUMERALS[degree];
  }
  var NUM = '(?:i{1,3}|iv|vi{0,2}|I{1,3}|IV|VI{0,2})';
  var ROMAN_RE = new RegExp('^([b#]?)(i{1,3}|iv|vi{0,2}|I{1,3}|IV|VI{0,2})(\\+maj7|\\+7|maj7|maj9|add9|sus2|sus4|m7|o7|[679]|o|0|\\+)?(?:/([b#]?' + NUM + '))?$');

  function parse_note_name(name) {
    var key = name.trim().toUpperCase().split('♭').join('B').split('♯').join('#');
    if (!(key in PITCH_CLASSES)) throw new Error('unknown note name: ' + name);
    return PITCH_CLASSES[key];
  }
  function note_name(pitch) { return NOTE_NAMES[P.mod(pitch, 12)] + (P.floordiv(pitch, 12) - 1); }
  function scale_pitch_classes(tonic, mode) {
    var iv = SCALES[mode] || SCALES.major;
    return iv.map(function (i) { return P.mod(tonic + i, 12); });
  }
  function is_minor(mode) { return MINOR_MODES.has(mode); }

  function Chord(symbol, root, quality, pcs, bass) {
    this.symbol = symbol; this.root = root; this.quality = quality; this.pitch_classes = pcs; this.bass = bass;
  }
  Object.defineProperty(Chord.prototype, 'tones', { get: function () { return this.pitch_classes; } });
  Chord.prototype.voice = function (low, high) {
    low = low === undefined ? 48 : low; high = high === undefined ? 72 : high;
    var notes = [], base = low + P.mod(this.bass - low, 12);
    notes.push(base);
    var prev = base, self = this;
    this.pitch_classes.forEach(function (pc) {
      if (pc === self.bass && notes.length === 1) return;
      var cand = prev + P.mod(pc - prev, 12);
      if (cand === prev) cand += 12;
      if (cand > high) { cand -= 12; if (cand <= prev) return; }
      notes.push(cand); prev = cand;
    });
    return Array.from(new Set(notes)).sort(function (a, b) { return a - b; });
  };
  Chord.prototype.nearest_tone = function (pitch) {
    var best = pitch, bd = 128;
    this.pitch_classes.forEach(function (pc) {
      for (var o = -1; o < 2; o++) {
        var cand = pitch + P.mod(pc - pitch, 12) + 12 * o, d = Math.abs(cand - pitch);
        if (d < bd) { best = cand; bd = d; }
      }
    });
    return best;
  };

  function parse_roman(symbol, tonic, mode) {
    var m = ROMAN_RE.exec(symbol.trim());
    if (!m) throw new Error('unparsable roman numeral: ' + symbol);
    var accidental = m[1], numeral = m[2], suffix = m[3] || '', secondary = m[4];
    var local_tonic = tonic;
    if (secondary) {
      var target = parse_roman(secondary, tonic, mode);
      local_tonic = target.root;
    }
    var scale = scale_pitch_classes(local_tonic, 'major');
    var degree = DEGREE_VALUES[numeral.toUpperCase()];
    var root = scale[degree % scale.length];
    if (accidental === 'b') root = P.mod(root - 1, 12);
    else if (accidental === '#') root = P.mod(root + 1, 12);
    var base_quality = P.isupper(numeral) ? (suffix === '+' ? 'aug' : 'maj') : ((suffix === 'o' || suffix === 'o7' || suffix === '0') ? 'dim' : 'min');
    var quality = (SUFFIX_MAP[suffix] || SUFFIX_MAP[''])[base_quality];
    var pcs = QUALITIES[quality].map(function (i) { return P.mod(root + i, 12); });
    return new Chord(symbol, root, quality, pcs, root);
  }
  function harmonic_pitch_classes(tonic, mode) {
    var parent = PARENT_SCALE[mode] || mode;
    var allowed = new Set(scale_pitch_classes(tonic, parent));
    if (BLUES_MODES.has(mode)) scale_pitch_classes(tonic, 'mixolydian').forEach(function (x) { allowed.add(x); });
    if (is_minor(mode)) allowed.add(P.mod(tonic + 11, 12));
    return allowed;
  }
  function degree_to_pitch(scale, root, degree) {
    var dm = P.divmod(degree, scale.length);
    return root + P.mod(scale[dm[1]] - scale[0], 12) + 12 * dm[0];
  }
  function nearest_degree(scale, root, pitch) {
    var bd = 0, bdist = 128, span = scale.length * 4;
    for (var d = -span; d < span; d++) {
      var dist = Math.abs(degree_to_pitch(scale, root, d) - pitch);
      if (dist < bdist) { bd = d; bdist = dist; }
    }
    return bd;
  }

  // ================================================================== chance
  var CHANCE_FIELDS = ['step', 'skip', 'repeat', 'leap_turns_back', 'cadence_lands_home', 'cadence_deceptive',
    'twin_answers', 'new_motif', 'drum_fill', 'ghost_note', 'bass_root', 'bass_fifth'];
  var CHANCE_DEFAULTS = { step: 0.55, skip: 0.20, repeat: 0.15, leap_turns_back: 0.90, cadence_lands_home: 0.80,
    cadence_deceptive: 0.30, twin_answers: 0.70, new_motif: 0.45, drum_fill: 0.55, ghost_note: 0.55, bass_root: 0.70, bass_fifth: 0.20 };
  function Chances(values) {
    var self = this;
    CHANCE_FIELDS.forEach(function (f) { self[f] = values && values[f] !== undefined ? values[f] : CHANCE_DEFAULTS[f]; });
  }
  Object.defineProperty(Chances.prototype, 'leap', { get: function () { return Math.max(0.0, 1.0 - this.step - this.skip - this.repeat); } });
  Object.defineProperty(Chances.prototype, 'bass_third', { get: function () { return Math.max(0.0, 1.0 - this.bass_root - this.bass_fifth); } });
  function pick(rng, options) {
    var total = 0;
    options.forEach(function (o) { total += Math.max(0.0, o[1]); });
    if (total <= 0) return options[0][0];
    var roll = rng.random() * total;
    for (var i = 0; i < options.length; i++) { roll -= Math.max(0.0, options[i][1]); if (roll <= 0) return options[i][0]; }
    return options[options.length - 1][0];
  }
  Chances.prototype.move = function (rng) { return pick(rng, [['repeat', this.repeat], ['step', this.step], ['skip', this.skip], ['leap', this.leap]]); };
  Chances.prototype.bass_tone = function (rng) { return pick(rng, [['root', this.bass_root], ['fifth', this.bass_fifth], ['third', this.bass_third]]); };
  Chances.prototype.to_dict = function () { var o = {}, self = this; CHANCE_FIELDS.forEach(function (f) { o[f] = P.round(self[f], 4); }); return o; };
  Chances.prototype.replace = function (changes) {
    var v = {}, self = this;
    CHANCE_FIELDS.forEach(function (f) { v[f] = self[f]; });
    Object.keys(changes).forEach(function (k) { if (k in v) v[k] = changes[k]; });
    return new Chances(v).clamp();
  };
  Chances.prototype.clamp = function () {
    var self = this;
    CHANCE_FIELDS.forEach(function (f) { self[f] = Math.max(0.0, Math.min(1.0, Number(self[f]))); });
    var total = this.step + this.skip + this.repeat;
    if (total > 1.0) { this.step /= total; this.skip /= total; this.repeat /= total; }
    if (this.bass_root + this.bass_fifth > 1.0) {
      var share = this.bass_root + this.bass_fifth;
      this.bass_root /= share; this.bass_fifth /= share;
    }
    return this;
  };
  function chances_from_entry(entry, base) {
    var c = base || new Chances(), ch = {};
    P.items(entry.chances || {}).forEach(function (kv) { if (CHANCE_FIELDS.indexOf(kv[0]) >= 0) ch[kv[0]] = kv[1]; });
    return c.replace(ch);
  }

  // =================================================================== parts
  var PARTS = ['melody', 'countermelody', 'harmony', 'bass', 'drums'];
  var PITCHED_PARTS = PARTS.slice(0, 4);
  var PART_NAMES = { melody: 'Melody', countermelody: 'Countermelody', harmony: 'Harmony', bass: 'Bass', drums: 'Drums' };
  var PART_CHANNELS = { melody: 0, countermelody: 1, harmony: 2, bass: 3, drums: 9 };
  var TREATMENTS = ['chords', 'ostinato', 'arpeggio'];
  var VOICE_PARTS = { melody: 'melody', countermelody: 'countermelody', chords: 'harmony', ostinato: 'harmony', arpeggio: 'harmony', bass: 'bass' };

  // ================================================================== rhythm
  var SIMPLE_CELLS = [
    [[2.0], 0.00, 0.45, 3.0], [[1.5, 0.5], 0.15, 0.65, 2.0], [[1.0], 0.00, 0.75, 4.0], [[-1.0], 0.00, 0.50, 2.0],
    [[0.5, 0.5], 0.25, 1.00, 4.0], [[-0.5, 0.5], 0.30, 1.00, 2.0], [[0.5, -0.5], 0.20, 0.85, 1.5], [[0.75, 0.25], 0.35, 1.00, 2.0],
    [[0.25, 0.75], 0.40, 1.00, 1.5], [[0.5, 0.25, 0.25], 0.50, 1.00, 2.5], [[0.25, 0.25, 0.5], 0.50, 1.00, 2.5],
    [[0.25, 0.25, 0.25, 0.25], 0.65, 1.00, 3.0], [[1 / 3, 1 / 3, 1 / 3], 0.45, 1.00, 1.5]];
  var COMPOUND_CELLS = [
    [[2.0], 0.00, 0.35, 2.0], [[1.0], 0.00, 0.55, 3.0], [[-1.0], 0.00, 0.40, 1.5], [[2 / 3, 1 / 3], 0.25, 1.00, 3.0],
    [[1 / 3, 1 / 3, 1 / 3], 0.35, 1.00, 4.0], [[1 / 3, -1 / 3, 1 / 3], 0.40, 1.00, 1.5], [[1 / 3, 2 / 3], 0.30, 1.00, 2.0],
    [[1 / 6, 1 / 6, 1 / 3, 1 / 3], 0.70, 1.00, 2.0], [[1 / 6, 1 / 6, 1 / 6, 1 / 6, 1 / 6, 1 / 6], 0.80, 1.00, 1.5]];
  function is_compound(meter) { return meter[1] === 8 && meter[0] % 3 === 0 && meter[0] > 3; }
  function pulse_length(meter) { return is_compound(meter) ? 1.5 : 4.0 / meter[1]; }
  function pulses_per_bar(meter) { return is_compound(meter) ? P.floordiv(meter[0], 3) : meter[0]; }
  function cell_weight(cell, density) {
    var low = cell[1], high = cell[2], weight = cell[3];
    if (!(low <= density && density <= high)) return 0.0;
    var centre = (low + high) / 2, span = Math.max(0.2, (high - low) / 2);
    return weight * Math.max(0.15, 1.0 - Math.abs(density - centre) / span);
  }
  function choose_cell(rng, density, compound, bias) {
    var cells = compound ? COMPOUND_CELLS : SIMPLE_CELLS, weighted = [];
    cells.forEach(function (cell) {
      var w = cell_weight(cell, density);
      if (bias) w *= 1.0 + (bias.get(cell[0], 0.0));
      if (w > 0) weighted.push([cell[0], w]);
    });
    if (!weighted.length) return [1.0];
    var total = P.sum(weighted.map(function (x) { return x[1]; }));
    var roll = rng.random() * total;
    for (var i = 0; i < weighted.length; i++) { roll -= weighted[i][1]; if (roll <= 0) return weighted[i][0]; }
    return weighted[weighted.length - 1][0];
  }
  function abssum(cell) { return P.sum(cell.map(Math.abs)); }
  function bar_rhythm(rng, meter, density, bias, start_on_downbeat) {
    if (start_on_downbeat === undefined) start_on_downbeat = true;
    var compound = is_compound(meter), pulse = pulse_length(meter), total = pulses_per_bar(meter);
    var onsets = [], position = 0.0, remaining = total;
    while (remaining > 1e-6) {
      var cell = choose_cell(rng, density, compound, bias);
      if (abssum(cell) > remaining + 1e-6) cell = [Math.min(1.0, remaining)];
      cell.forEach(function (value) {
        var length = Math.abs(value) * pulse;
        if (value > 0) onsets.push([position, length]);
        position += length;
      });
      remaining -= abssum(cell);
    }
    if (start_on_downbeat && (!onsets.length || onsets[0][0] > 1e-6)) {
      onsets.unshift([0.0, pulse]);
      onsets = dedupe_onsets(onsets);
    }
    return onsets;
  }
  function dedupe_onsets(onsets) {
    var out = [];
    P.sorted(onsets).forEach(function (od) {
      if (out.length && od[0] - out[out.length - 1][0] < 1e-6) return;
      if (out.length) { var prev = out[out.length - 1]; out[out.length - 1] = [prev[0], Math.min(prev[1], od[0] - prev[0])]; }
      out.push([od[0], od[1]]);
    });
    return out.filter(function (x) { return x[1] > 1e-6; });
  }
  function apply_swing(onset, swing, meter) {
    if (swing <= 1e-6 || is_compound(meter)) return onset;
    var position = P.mod(onset, 1.0);
    if (Math.abs(position - 0.5) < 1e-6) return onset + swing * 0.5;
    return onset;
  }

  // ================================================================= cadence
  var PAC = 'PAC', IAC = 'IAC', PC = 'PC', DC = 'DC', HC = 'HC';
  function CadenceType(key, name, conclusive, degrees, seventh, melody_target, root_position) {
    this.key = key; this.name = name; this.conclusive = conclusive; this.degrees = degrees; this.seventh = seventh;
    this.melody_target = melody_target; this.root_position = root_position;
  }
  var CADENCES = {
    PAC: new CadenceType(PAC, 'perfect authentic', true, [4, 0], true, 'tonic', true),
    IAC: new CadenceType(IAC, 'imperfect authentic', true, [4, 0], false, 'chord tone', false),
    PC: new CadenceType(PC, 'plagal', true, [3, 0], false, 'tonic', true),
    DC: new CadenceType(DC, 'deceptive', false, [4, 5], true, 'chord tone', false),
    HC: new CadenceType(HC, 'half', false, [4], false, 'chord tone', false)
  };
  var STRENGTH = { HC: 0, DC: 1, IAC: 2, PC: 3, PAC: 4 };
  function cadence_get(kind) { return CADENCES[kind || ''] || null; }
  function is_conclusive(kind) { var c = cadence_get(kind); return !!(c && c.conclusive); }

  // ==================================================================== form
  var SECTION_LENGTHS = [4, 8, 16], LADDER = [4, 8, 16, 32, 64], MAX_BARS = 128;
  var FORMS = {
    motif: [['A', 'statement']],
    period: [['A', 'antecedent'], ["A'", 'consequent']],
    strophic: [['A', 'verse'], ["A'", 'verse'], ["A''", 'verse']],
    binary: [['A', 'first strain'], ['B', 'second strain']],
    binary_repeated: [['A', 'first strain'], ["A'", 'first strain repeated'], ['B', 'second strain'], ["B'", 'second strain repeated']],
    ternary: [['A', 'statement'], ['B', 'contrast'], ["A'", 'return']],
    aaba: [['A', 'verse'], ["A'", 'verse'], ['B', 'bridge'], ["A''", 'verse']],
    rondo: [['A', 'refrain'], ['B', 'first episode'], ["A'", 'refrain'], ['C', 'second episode'], ["A''", 'refrain']],
    rondo_seven: [['A', 'refrain'], ['B', 'first episode'], ["A'", 'refrain'], ['C', 'second episode'], ["A''", 'refrain'],
      ["B'", 'first episode returns'], ["A'''", 'refrain']],
    medley: [['A', 'first tune'], ['B', 'second tune'], ['C', 'third tune'], ['D', 'fourth tune']],
    through_composed: [['A', 'first idea'], ['B', 'second idea'], ['C', 'third idea'], ['D', 'fourth idea'], ['E', 'closing idea']],
    sonata: [['A', 'first subject'], ['B', 'second subject'], ['C', 'development'], ["A'", 'recapitulation'], ["B'", 'second subject in the tonic']],
    fugue: [['A', 'subject'], ["A'", 'answer'], ['B', 'episode'], ["A''", 'middle entry'], ["B'", 'episode'], ["A'''", 'final entry']]
  };
  var OPEN_ROLES = ['antecedent', 'bridge', 'episode', 'development', 'contrast', 'first strain', 'second subject'];
  var GENRE_FORMS = {
    baroque: ['binary', 'binary_repeated', 'fugue', 'ternary'], classical: ['ternary', 'rondo', 'sonata', 'period'],
    romantic_era: ['ternary', 'rondo', 'through_composed'], folk: ['strophic', 'binary', 'period'],
    celtic: ['binary_repeated', 'binary', 'strophic'], blues: ['strophic'], jazz: ['aaba', 'rondo'], ragtime: ['rondo', 'medley'],
    gospel: ['strophic', 'aaba'], pop: ['aaba', 'strophic'], rnb: ['aaba'], lofi: ['strophic', 'aaba'], ballad: ['aaba', 'ternary'],
    ambient: ['through_composed', 'strophic'], minimal: ['strophic', 'through_composed'], cinematic: ['ternary', 'through_composed', 'rondo'],
    house: ['strophic', 'binary'], techno: ['strophic'], trap: ['aaba', 'strophic'], chiptune: ['binary_repeated', 'ternary'],
    rock: ['aaba', 'strophic'], waltz: ['ternary', 'rondo'], tango: ['binary', 'ternary'], bossa: ['aaba'],
    country: ['strophic', 'aaba'], bluegrass: ['binary_repeated', 'strophic'], soul: ['aaba', 'strophic'], doo_wop: ['aaba', 'strophic'],
    rockabilly: ['strophic', 'aaba'], punk: ['strophic', 'binary'], ska: ['aaba', 'strophic'], reggae: ['strophic', 'aaba'],
    synthpop: ['aaba', 'strophic'], city_pop: ['aaba'], lounge: ['aaba', 'ternary'],
    disco: ['strophic', 'binary'], funk: ['strophic', 'binary'], trance: ['binary', 'strophic'], drum_and_bass: ['binary', 'strophic'],
    dubstep: ['binary', 'strophic'], uk_garage: ['strophic', 'binary'], synthwave: ['binary', 'strophic', 'ternary'],
    vaporwave: ['strophic', 'through_composed'], trip_hop: ['strophic', 'aaba'], boom_bap: ['strophic', 'aaba'], afrobeat: ['strophic', 'binary'],
    bebop: ['aaba', 'binary'], big_band: ['aaba', 'rondo'], dixieland: ['medley', 'rondo', 'binary'], modal_jazz: ['binary', 'through_composed'],
    smooth_jazz: ['aaba', 'ternary'], boogie_woogie: ['strophic'],
    polka: ['binary_repeated', 'rondo', 'medley'], march: ['rondo', 'medley', 'binary_repeated'], klezmer: ['binary_repeated', 'rondo'],
    salsa: ['binary', 'strophic'], samba: ['aaba', 'binary'], cumbia: ['strophic', 'binary'], flamenco: ['through_composed', 'binary', 'strophic'],
    renaissance: ['binary', 'through_composed', 'period'], impressionist: ['ternary', 'through_composed'], hymn: ['strophic', 'period'],
    barbershop: ['aaba', 'strophic'], new_age: ['through_composed', 'strophic'], lullaby: ['strophic', 'period', 'binary'],
    metal: ['binary', 'ternary', 'through_composed'], prog_rock: ['through_composed', 'rondo', 'medley'], surf: ['binary_repeated', 'aaba'],
    reggaeton: ['strophic', 'binary'], bachata: ['aaba', 'strophic'], mariachi: ['strophic', 'binary_repeated', 'ternary'],
    zydeco: ['binary_repeated', 'strophic']
  };
  var PLAGAL_GENRES = new Set(['gospel', 'folk', 'celtic', 'ambient', 'hymn', 'renaissance', 'soul', 'country', 'new_age', 'reggae']);

  function snap_to_ladder(bars) { return P.min(LADDER, function (n) { return [Math.abs(n - bars), n]; }); }
  function letter_of(label) { return P.rstrip(label, "'"); }

  function Section(o) {
    this.label = o.label; this.bars = o.bars; this.start_bar = o.start_bar; this.role = o.role || '';
    this.cadence = o.cadence || PAC; this.transpose = o.transpose || 0; this.progression = o.progression || [];
    this.progression_labels = o.progression_labels || []; this.density = o.density === undefined ? 0.5 : o.density;
    this.register = o.register || 0; this.velocity = o.velocity === undefined ? 78 : o.velocity; this.pattern = o.pattern || 'block';
  }
  Object.defineProperty(Section.prototype, 'letter', { get: function () { return letter_of(this.label); } });
  Object.defineProperty(Section.prototype, 'variation', { get: function () { return P.count(this.label, "'"); } });
  Section.prototype.to_dict = function () {
    return { label: this.label, bars: this.bars, startBar: this.start_bar + 1, role: this.role, cadence: this.cadence,
      progression: this.progression, pattern: this.pattern };
  };

  function choose_form(spec, rng) {
    if (spec.forms && spec.forms.length) for (var i = 0; i < spec.forms.length; i++) if (FORMS[spec.forms[i]]) return spec.forms[i];
    var target = spec.bars;
    if (target <= 4) return 'motif';
    if (target <= 8) return 'period';
    var pool = [];
    (spec.genres || []).forEach(function (g) { pool = pool.concat(GENRE_FORMS[g] || []); });
    if (!pool.length) pool = target >= 48 ? ['sonata', 'rondo', 'rondo_seven', 'through_composed', 'medley'] : ['aaba', 'ternary', 'strophic', 'binary'];
    if (target >= 48) {
      var richer = pool.filter(function (n) { return FORMS[n].length >= 4; });
      pool = richer.length ? richer : pool;
    }
    return rng.choice(pool);
  }
  function section_length(count, target) {
    var best = P.min(SECTION_LENGTHS, function (n) { return [Math.abs(count * n - target), n]; });
    while (count * best > MAX_BARS && best > SECTION_LENGTHS[0]) best = SECTION_LENGTHS[SECTION_LENGTHS.indexOf(best) - 1];
    return best;
  }
  function plan_cadences(layout, rng, plagal_bias, chances) {
    chances = chances || new Chances();
    var plan = [], total = layout.length;
    layout.forEach(function (lr, index) {
      var letter = letter_of(lr[0]), role = lr[1];
      var next_letter = index + 1 < total ? letter_of(layout[index + 1][0]) : null;
      if (index === total - 1) plan.push(rng.random() < plagal_bias ? PC : PAC);
      else if (OPEN_ROLES.some(function (r) { return role.indexOf(r) >= 0; })) plan.push(HC);
      else if (next_letter === letter && rng.random() < chances.twin_answers) plan.push(HC);
      else if (rng.random() < chances.cadence_lands_home) plan.push(IAC);
      else if (index === total - 2 && rng.random() < chances.cadence_deceptive) plan.push(DC);
      else plan.push(HC);
    });
    return plan;
  }
  function plan_form(spec, rng, make_progression) {
    var form = choose_form(spec, rng), layout = FORMS[form];
    var bars = section_length(layout.length, spec.bars);
    if (layout.length * bars !== spec.bars && LADDER.indexOf(spec.bars) < 0) { layout = [['A', 'statement']]; bars = spec.bars; }
    var plagal = (spec.genres || []).some(function (g) { return PLAGAL_GENRES.has(g); }) ? 0.35 : 0.06;
    var plan = plan_cadences(layout, rng, plagal, spec.chances);
    var bases = new P.Dict(), harmonies = new P.Dict(), sections = [], start = 0;
    layout.forEach(function (lr, i) {
      var label = lr[0], role = lr[1], cadence = plan[i];
      var letter = letter_of(label), variation = P.count(label, "'");
      var key = [letter, cadence];
      if (!harmonies.has(key)) {
        if (!bases.has(letter)) {
          if (make_progression) bases.set(letter, make_progression(Math.min(bars, 8), cadence));
          else if (letter === 'A' || !bases.size) bases.set(letter, [spec.progression.slice(), (spec.progression_labels.length ? spec.progression_labels : spec.progression).slice()]);
          else bases.set(letter, bases.get(bases.keys()[0]));
          harmonies.set(key, bases.get(letter));
        } else if (make_progression) harmonies.set(key, make_progression(Math.min(bars, 8), cadence, bases.get(letter)));
        else harmonies.set(key, bases.get(letter));
      }
      var h = harmonies.get(key);
      var transpose = (form === 'fugue' && role.indexOf('answer') >= 0) ? 7 : 0;
      var contrast = letter !== 'A';
      sections.push(new Section({
        label: label, bars: bars, start_bar: start, role: role, cadence: cadence, transpose: transpose,
        progression: h[0].slice(), progression_labels: h[1].slice(),
        density: spec.density * (contrast ? 1.2 : 1.0 + 0.05 * variation),
        register: spec.register + (contrast ? 1 : 0),
        velocity: spec.velocity + (contrast ? 5 : 2 * variation),
        pattern: spec.pattern
      }));
      start += bars;
    });
    return sections;
  }
  function describe(sections) { return sections.map(function (s) { return s.label; }).join(' '); }

  // =================================================================== vocab
  var WORD_RE = /[a-z0-9#&+/-]+/g;
  function normalise(text) {
    text = text.toLowerCase().split('&').join(' and ').split('_').join(' ');
    text = text.split('-').join(' ');
    return (text.match(WORD_RE) || []).join(' ');
  }
  function Priors() {
    this.tempo_low = 88.0; this.tempo_high = 112.0; this.tempo_scale = 1.0;
    this.modes = new P.Dict(); this.meters = new P.Dict(); this.progressions = []; this.patterns = new P.Dict();
    this.density = 0.5; this.swing = 0.0; this.extensions = 0.2; this.register = 0.0; this.velocity = 78.0;
    this.humanize = 1.0; this.ornament = 0.35; this.chances = new Chances(); this.chromaticism = 0.25; this.functional = 0.5;
  }
  function addTo(d, obj, weight) { P.items(obj || {}).forEach(function (kv) { d.set(kv[0], d.get(kv[0], 0.0) + kv[1] * weight); }); }
  Priors.prototype.apply_genre = function (entry, weight) {
    if (weight === undefined) weight = 1.0;
    var t = entry.tempo || [this.tempo_low, this.tempo_high], self = this;
    this.tempo_low = this.tempo_low * (1 - weight) + t[0] * weight;
    this.tempo_high = this.tempo_high * (1 - weight) + t[1] * weight;
    addTo(this.modes, entry.modes, weight);
    addTo(this.meters, entry.meters, weight);
    (entry.progressions || []).forEach(function (pr) { self.progressions.push([pr.c.slice(), (pr.w === undefined ? 1 : pr.w) * weight]); });
    addTo(this.patterns, entry.patterns, weight);
    ['density', 'swing', 'extensions', 'register', 'velocity', 'chromaticism', 'functional', 'ornament'].forEach(function (k) {
      if (k in entry) self[k] = self[k] * (1 - weight) + entry[k] * weight;
    });
    if (entry.chances && Object.keys(entry.chances).length) {
      var wanted = chances_from_entry(entry);
      ['step', 'skip', 'repeat', 'leap_turns_back', 'cadence_lands_home', 'cadence_deceptive', 'twin_answers', 'new_motif',
        'bass_root', 'bass_fifth', 'drum_fill', 'ghost_note'].forEach(function (n) {
        self.chances[n] = self.chances[n] * (1 - weight) + wanted[n] * weight;
      });
      this.chances.clamp();
    }
  };
  Priors.prototype.apply_modifier = function (entry) {
    var self = this;
    addTo(this.modes, entry.modes, 1);
    addTo(this.meters, entry.meters, 1);
    (entry.progressions || []).forEach(function (pr) { self.progressions.push([pr.c.slice(), pr.w === undefined ? 1 : pr.w]); });
    addTo(this.patterns, entry.patterns, 1);
    function g(k, d) { return k in entry ? entry[k] : d; }
    this.tempo_scale *= g('tempo_scale', 1.0);
    this.density += g('density_delta', 0.0);
    this.extensions += g('extensions_delta', 0.0);
    this.register += g('register_delta', 0.0);
    this.velocity += g('velocity_delta', 0.0);
    this.chromaticism += g('chromaticism_delta', 0.0);
    this.ornament += g('ornament_delta', 0.0);
    if ('swing' in entry) this.swing = entry.swing;
    this.humanize *= g('humanize_scale', 1.0);
  };
  function Match(kind, tag, phrase, start, end) { this.kind = kind; this.tag = tag; this.phrase = phrase; this.start = start; this.end = end; }
  var CHARACTER_KINDS = ['genre', 'mood', 'descriptor'];
  var AXES = ['character', 'scale', 'form', 'voice', 'role'];
  function axis_of(kind) { return CHARACTER_KINDS.indexOf(kind) >= 0 ? 'character' : kind; }

  function Vocabulary(data) {
    this.data = data;
    this.genres = data.genres || {}; this.moods = data.moods || {}; this.descriptors = data.descriptors || {};
    this.roles = data.roles || {}; this.scales = data.scales || {}; this.forms = data.forms || {}; this.voices = data.voices || {};
    this._phrases = this._build_phrase_index();
  }
  Vocabulary.prototype._build_phrase_index = function () {
    var by = new P.Dict();
    [['genre', this.genres], ['mood', this.moods], ['descriptor', this.descriptors], ['role', this.roles],
     ['scale', this.scales], ['form', this.forms], ['voice', this.voices]].forEach(function (kg) {
      var kind = kg[0];
      P.items(kg[1]).forEach(function (te) {
        var tag = te[0], entry = te[1];
        // a set in Python, whose order Python itself does not fix
        var terms = P.unique((entry.synonyms || []).concat([tag.split('_').join(' ')]).concat(entry.label ? [entry.label.toLowerCase()] : []));
        terms.forEach(function (term) {
          var phrase = normalise(term);
          if (!phrase) return;
          var claims = by.setdefault(phrase, []);
          if (!claims.some(function (c) { return c[0] === kind && c[1] === tag; })) claims.push([kind, tag]);
        });
      });
    });
    var phrases = by.items();
    return P.sorted(phrases, function (p) { return [-p[0].split(' ').length, -p[0].length]; });
  };
  Vocabulary.prototype.find = function (text) {
    var hay = ' ' + normalise(text) + ' ', n = hay.length;
    var taken = {};
    AXES.forEach(function (a) { taken[a] = new Array(n).fill(false); });
    var closed = new Array(n).fill(false), matches = [];
    this._phrases.forEach(function (pc) {
      var phrase = pc[0], claims = pc[1], needle = ' ' + phrase + ' ';
      var names_character = claims.some(function (c) { return CHARACTER_KINDS.indexOf(c[0]) >= 0; });
      var start = hay.indexOf(needle);
      while (start !== -1) {
        var a = start + 1, b = start + needle.length - 1, claimed = false, i;
        var anyClosed = false;
        for (i = a; i < b; i++) if (closed[i]) { anyClosed = true; break; }
        if (!anyClosed) {
          claims.forEach(function (c) {
            var lane = taken[axis_of(c[0])];
            for (var j = a; j < b; j++) if (lane[j]) return;
            for (j = a; j < b; j++) lane[j] = true;
            matches.push(new Match(c[0], c[1], phrase, start, start + needle.length));
            claimed = true;
          });
        }
        if (claimed) {
          if (names_character) for (i = a; i < b; i++) closed[i] = true;
          break;
        }
        start = hay.indexOf(needle, start + 1);
      }
    });
    return P.sorted(matches, function (m) { return m.start; });
  };
  function dedupe_by_tag(matches) {
    var seen = new Set(), out = [];
    matches.forEach(function (m) { var k = m.kind + '\u0000' + m.tag; if (!seen.has(k)) { seen.add(k); out.push(m); } });
    return out;
  }
  Vocabulary.prototype.priors_for = function (matches) {
    var priors = new Priors(), self = this;
    var genres = dedupe_by_tag(matches.filter(function (m) { return m.kind === 'genre'; }));
    if (genres.length) {
      var share = 1.0 / genres.length;
      genres.forEach(function (m, i) { priors.apply_genre(self.genres[m.tag], i === 0 ? 1.0 : share); });
    } else {
      priors.modes = new P.Dict([['major', 3], ['minor', 3], ['dorian', 1], ['mixolydian', 1]]);
      priors.meters = new P.Dict([['4/4', 10], ['3/4', 2]]);
      priors.patterns = new P.Dict([['block', 3], ['arpeggio_up', 2], ['arpeggio_updown', 2], ['ballad', 1]]);
      priors.progressions = [[['I', 'V', 'vi', 'IV'], 3], [['i', 'bVI', 'bIII', 'bVII'], 3], [['I', 'vi', 'IV', 'V'], 2], [['i', 'iv', 'V7', 'i'], 2]];
    }
    dedupe_by_tag(matches).forEach(function (m) {
      if (m.kind === 'mood') priors.apply_modifier(self.moods[m.tag]);
      else if (m.kind === 'descriptor') priors.apply_modifier(self.descriptors[m.tag]);
    });
    return priors;
  };

  Object.assign(C, {
    SHARP_NAMES: SHARP_NAMES, FLAT_NAMES: FLAT_NAMES, Key: Key, key_for: key_for, spell_as: spell_as, detect_chord: detect_chord,
    SV_SCALES: SV_SCALES, ROOTS_BY_NAME: ROOTS_BY_NAME,
    PITCH_CLASSES: PITCH_CLASSES, NOTE_NAMES: NOTE_NAMES, SCALES: SCALES, PARENT_SCALE: PARENT_SCALE, MINOR_MODES: MINOR_MODES,
    BLUES_MODES: BLUES_MODES, QUALITIES: QUALITIES, ROMAN_BY_INTERVAL: ROMAN_BY_INTERVAL, roman_for_degree: roman_for_degree,
    parse_note_name: parse_note_name, note_name: note_name, scale_pitch_classes: scale_pitch_classes, is_minor: is_minor,
    Chord: Chord, parse_roman: parse_roman, harmonic_pitch_classes: harmonic_pitch_classes, degree_to_pitch: degree_to_pitch,
    nearest_degree: nearest_degree,
    Chances: Chances, CHANCE_FIELDS: CHANCE_FIELDS, chances_from_entry: chances_from_entry,
    PARTS: PARTS, PITCHED_PARTS: PITCHED_PARTS, PART_NAMES: PART_NAMES, PART_CHANNELS: PART_CHANNELS, TREATMENTS: TREATMENTS,
    VOICE_PARTS: VOICE_PARTS,
    is_compound: is_compound, pulse_length: pulse_length, pulses_per_bar: pulses_per_bar, choose_cell: choose_cell,
    bar_rhythm: bar_rhythm, apply_swing: apply_swing,
    PAC: PAC, IAC: IAC, PC: PC, DC: DC, HC: HC, CADENCES: CADENCES, STRENGTH: STRENGTH, cadence_get: cadence_get, is_conclusive: is_conclusive,
    FORMS: FORMS, LADDER: LADDER, snap_to_ladder: snap_to_ladder, Section: Section, choose_form: choose_form, plan_form: plan_form,
    plan_cadences: plan_cadences, describe: describe,
    normalise: normalise, Priors: Priors, Match: Match, Vocabulary: Vocabulary
  });
})(typeof module === 'object' && module.exports
  ? (module.exports = (globalThis.MiddawComposer = globalThis.MiddawComposer || {}))
  : (globalThis.MiddawComposer = globalThis.MiddawComposer || {}));
