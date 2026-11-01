/* The composer end to end, ported line for line: middaw/spec.py, prompt.py,
 * render.py and the `--json` answer of middaw/__main__.py. Load core.js,
 * functional.js and music.js first, then call `MiddawComposer.load(tags,
 * drums)` with data/vocab/tags.json and drums.json (as parsed JSON). */
(function (C) {
  'use strict';
  var P = globalThis.MiddawPy, R = globalThis.MiddawPyRandom;

  // =================================================================== spec
  var SPEC_FIELDS = ['prompt', 'seed', 'tonic', 'mode', 'tempo', 'meter', 'bars', 'density', 'swing', 'extensions', 'register',
    'velocity', 'humanize', 'progression', 'progression_labels', 'chromaticism', 'ornament', 'pattern', 'harmony', 'chances',
    'genres', 'moods', 'descriptors', 'scales', 'forms', 'voices', 'form', 'form_name', 'matched_terms', 'unmatched_terms',
    'corpus_sources', 'tonic_spelling', 'ticks_per_beat'];
  function MusicSpec(o) {
    o = o || {};
    var d = { prompt: '', seed: 0, tonic: 0, mode: 'major', tempo: 100, meter: [4, 4], bars: 16, density: 0.5, swing: 0.0,
      extensions: 0.2, register: 0, velocity: 78, humanize: 1.0, progression: ['I', 'V', 'vi', 'IV'], progression_labels: [],
      chromaticism: 0.25, ornament: 0.35, pattern: 'block', harmony: 'chords', chances: null, genres: [], moods: [], descriptors: [],
      scales: [], forms: [], voices: ['melody', 'countermelody', 'harmony', 'bass'], form: '', form_name: '', matched_terms: [],
      unmatched_terms: [], corpus_sources: [], tonic_spelling: null, ticks_per_beat: 480 };
    var self = this;
    SPEC_FIELDS.forEach(function (f) { self[f] = o[f] !== undefined ? o[f] : d[f]; });
    if (!this.chances) this.chances = new C.Chances();
  }
  Object.defineProperty(MusicSpec.prototype, 'beats_per_bar', { get: function () { return this.meter[0] * 4.0 / this.meter[1]; } });
  Object.defineProperty(MusicSpec.prototype, 'key_name', { get: function () { return this.key().label; } });
  Object.defineProperty(MusicSpec.prototype, 'is_minor', { get: function () { return C.is_minor(this.mode); } });
  Object.defineProperty(MusicSpec.prototype, 'duration_seconds', { get: function () { return this.bars * this.beats_per_bar * 60.0 / this.tempo; } });
  MusicSpec.prototype.key = function () { return C.key_for(this.tonic, this.mode, this.tonic_spelling); };
  MusicSpec.prototype.replace = function (changes) {
    var o = {}, self = this;
    SPEC_FIELDS.forEach(function (f) { o[f] = self[f]; });
    Object.keys(changes).forEach(function (k) { o[k] = changes[k]; });
    return new MusicSpec(o);
  };
  MusicSpec.prototype.clamp = function () {
    this.tempo = Math.trunc(Math.max(30, Math.min(240, this.tempo)));
    this.bars = Math.trunc(Math.max(1, Math.min(128, this.bars)));
    this.density = Math.max(0.12, Math.min(1.0, this.density));
    this.swing = Math.max(0.0, Math.min(0.5, this.swing));
    this.extensions = Math.max(0.0, Math.min(1.0, this.extensions));
    this.register = Math.trunc(Math.max(-4, Math.min(4, this.register)));
    this.velocity = Math.trunc(Math.max(20, Math.min(120, this.velocity)));
    this.humanize = Math.max(0.0, Math.min(2.0, this.humanize));
    this.chromaticism = Math.max(0.0, Math.min(1.0, this.chromaticism));
    this.ornament = Math.max(0.0, Math.min(1.0, this.ornament));
    this.chances.clamp();
    this.tonic = P.mod(this.tonic, 12);
    return this;
  };
  MusicSpec.prototype.to_dict = function () {
    var o = {}, self = this;
    SPEC_FIELDS.forEach(function (f) { o[f] = self[f]; });
    var ch = {};
    C.CHANCE_FIELDS.forEach(function (f) { ch[f] = self.chances[f]; });
    o.chances = ch;
    o.meter = this.meter[0] + '/' + this.meter[1];
    o.key = this.key_name;
    o.duration_seconds = P.round(this.duration_seconds, 2);
    return o;
  };
  MusicSpec.prototype.summary = function () {
    var bits = [this.key_name, this.tempo + ' BPM', this.meter[0] + '/' + this.meter[1], this.bars + ' bars',
      this.form ? this.form_name.split('_').join(' ') + ': ' + this.form : '',
      this.progression.slice(0, 8).join(' ') + (this.progression.length > 8 ? '\u2026' : '')];
    var tags = this.genres.concat(this.moods);
    if (tags.length) bits.unshift(tags.join(', '));
    return bits.filter(function (b) { return b; }).join(' | ');
  };

  // ================================================================= prompt
  var FORM_IMPLIES_GENRE = { fugue: 'baroque', sonata: 'classical', rondo: 'classical', rondo_seven: 'classical', binary: 'baroque',
    binary_repeated: 'baroque', ternary: 'classical', aaba: 'jazz', strophic: 'folk', medley: 'ragtime' };
  var MODE_WORDS = { major: 'major', maj: 'major', ionian: 'major', minor: 'minor', min: 'minor', aeolian: 'aeolian',
    'harmonic minor': 'harmonic_minor', 'melodic minor': 'melodic_minor', dorian: 'dorian', phrygian: 'phrygian', lydian: 'lydian',
    mixolydian: 'mixolydian', locrian: 'locrian', pentatonic: 'major_pentatonic', 'major pentatonic': 'major_pentatonic',
    'minor pentatonic': 'minor_pentatonic', 'blues scale': 'blues', 'whole tone': 'whole_tone' };
  var NOTE_TOKEN = '(?:[a-g](?:\\s?(?:sharp|flat|#|b))?)';
  var KEY_RE = new RegExp('\\b(?:in|key\\s+of)\\s+(' + NOTE_TOKEN + ')(?:\\s+(harmonic minor|melodic minor|major pentatonic|minor pentatonic|' +
    'whole tone|blues scale|major|minor|maj|min|ionian|aeolian|dorian|phrygian|lydian|mixolydian|locrian|pentatonic))?\\b', 'i');
  var BARE_MODE_RE = /\b(harmonic minor|melodic minor|major pentatonic|minor pentatonic|whole tone|blues scale|dorian|phrygian|lydian|mixolydian|locrian|major|minor)\b/i;
  var BPM_RE = /\b(\d{2,3})\s*(?:bpm|beats per minute)\b/i;
  var AT_TEMPO_RE = /\bat\s+(\d{2,3})\b/i;
  var METER_RE = /\b(\d{1,2})\s*\/\s*(1|2|4|8|16)\b/;
  var BARS_RE = /\b(\d{1,3})\s*(?:bar|bars|measure|measures)\b/i;
  var SECONDS_RE = /\b(\d{1,3})\s*(?:second|seconds|sec|secs)\b/i;
  var MINUTES_RE = /\b(\d{1,2})\s*(?:minute|minutes|min)\b/i;
  var SEED_RE = /\bseed\s*[:=]?\s*(\d{1,10})\b/i;
  var STOPWORDS = new Set(('a an the and or of in on with for to at some make create generate write give me want like something that is it ' +
    'sounds sound sounding feel feels vibe vibes track piece loop idea please bars bar bpm key song tune i d my you can would be more very ' +
    'really kind sort bit little but then into over as its this playing play piano keys keyboard instrument midi pattern loop build part ' +
    'section long short new about around one two four eight sixteen seconds minutes minute second bpm tempo time signature notes note').split(' '));

  function pick_weighted(rng, weights, fallback) {
    var items = weights.items().filter(function (kv) { return kv[1] > 0; });
    if (!items.length) return fallback;
    var total = P.sum(items.map(function (kv) { return kv[1]; })), roll = rng.random() * total;
    for (var i = 0; i < items.length; i++) { roll -= items[i][1]; if (roll <= 0) return items[i][0]; }
    return items[items.length - 1][0];
  }
  function extract_key(text) {
    var m = KEY_RE.exec(text), tonic = null, mode = null, spelling = null;
    if (m) {
      var raw = m[1].toLowerCase().split(' ').join('');
      raw = raw.split('sharp').join('#').split('flat').join('b');
      try { tonic = C.parse_note_name(raw); spelling = raw[0].toUpperCase() + raw.slice(1); } catch (e) { tonic = null; }
      if (m[2]) mode = MODE_WORDS[m[2].toLowerCase()] || null;
    }
    if (mode === null) {
      var bare = BARE_MODE_RE.exec(text);
      if (bare) mode = MODE_WORDS[bare[1].toLowerCase()] || null;
    }
    return [tonic, mode, spelling];
  }
  function extract_tempo(text) {
    var m = BPM_RE.exec(text) || AT_TEMPO_RE.exec(text);
    if (m) { var bpm = parseInt(m[1], 10); if (bpm >= 30 && bpm <= 240) return bpm; }
    return null;
  }
  function extract_meter(text) {
    var m = METER_RE.exec(text);
    if (m) { var num = parseInt(m[1], 10), den = parseInt(m[2], 10); if (num >= 1 && num <= 16) return [num, den]; }
    return null;
  }
  function leftover_terms(text, matched, directives) {
    var words = C.normalise(text).split(' ').filter(function (w) { return w; });
    var consumed = new Set();
    matched.forEach(function (p) { p.split(' ').forEach(function (w) { consumed.add(w); }); });
    directives.forEach(function (s) { C.normalise(s).split(' ').forEach(function (w) { if (w) consumed.add(w); }); });
    var out = [];
    words.forEach(function (w) {
      if (consumed.has(w) || STOPWORDS.has(w) || /^[0-9]+$/.test(w)) return;
      if (/^\d+\/\d+$/.test(w)) return;
      if (out.indexOf(w) < 0) out.push(w);
    });
    return out;
  }
  var MODE_DEFAULT_PROGRESSIONS = {
    major: ['I', 'V', 'vi', 'IV'], ionian: ['I', 'V', 'vi', 'IV'], lydian: ['I', 'II', 'I', 'V'], mixolydian: ['I', 'bVII', 'IV', 'I'],
    major_pentatonic: ['I', 'V', 'vi', 'IV'], whole_tone: ['I', 'II', 'I', 'II'], minor: ['i', 'bVI', 'bIII', 'bVII'],
    aeolian: ['i', 'bVI', 'bIII', 'bVII'], harmonic_minor: ['i', 'iv', 'V7', 'i'], melodic_minor: ['i', 'IV', 'V7', 'i'],
    dorian: ['i', 'bVII', 'IV', 'i'], phrygian: ['i', 'bII', 'bVII', 'i'], locrian: ['io', 'bVI', 'bVII', 'io'],
    minor_pentatonic: ['i', 'bVII', 'iv', 'i'], blues: ['i7', 'iv7', 'i7', 'V7']
  };
  var TONIC_CHORD_RE = /^([b#]?)(iii|iv|ii|i|vii|vi|v|III|IV|II|I|VII|VI|V)/;
  function progression_is_minor(chords) {
    for (var i = 0; i < chords.length; i++) {
      var m = TONIC_CHORD_RE.exec(chords[i]);
      if (m && !m[1] && m[2].toUpperCase() === 'I') return P.islower(m[2]);
    }
    return chords.some(function (s) { return s.slice(0, 1) === 'b'; });
  }
  function progression_fit(chords, spec) {
    var allowed = C.harmonic_pitch_classes(spec.tonic, spec.mode), total = 0, fitting = 0;
    for (var i = 0; i < chords.length; i++) {
      if (chords[i].indexOf('/') >= 0) continue;
      var chord;
      try { chord = C.parse_roman(chords[i], spec.tonic, spec.mode); } catch (e) { return 0.0; }
      chord.pitch_classes.forEach(function (pc) { total++; if (allowed.has(pc)) fitting++; });
    }
    return total === 0 ? 1.0 : fitting / total;
  }
  var GENRE_TREATMENT = { minimal: 'ostinato', techno: 'ostinato', cinematic: 'ostinato', funk: 'ostinato', afrobeat: 'ostinato',
    metal: 'ostinato', dubstep: 'ostinato', drum_and_bass: 'ostinato', trap: 'ostinato', boogie_woogie: 'ostinato', salsa: 'ostinato',
    prog_rock: 'ostinato', house: 'ostinato', chiptune: 'arpeggio', trance: 'arpeggio', synthwave: 'arpeggio', new_age: 'arpeggio',
    impressionist: 'arpeggio', lullaby: 'arpeggio', bluegrass: 'arpeggio', bachata: 'arpeggio' };
  function choose_treatment(requested, spec) {
    for (var i = 0; i < requested.length; i++) if (C.TREATMENTS.indexOf(requested[i]) >= 0) return requested[i];
    for (var j = 0; j < spec.genres.length; j++) if (GENRE_TREATMENT[spec.genres[j]]) return GENRE_TREATMENT[spec.genres[j]];
    return 'chords';
  }
  var NO_DRUMS_RE = /\b(?:no|without|sans)\s+(?:drums?|percussion|beat|kit)\b|\bundrummed\b|\bdrumless\b|\bunaccompanied\b/;
  function wants_drums(text, spec, roles) {
    if (NO_DRUMS_RE.test(C.normalise(text))) return false;
    if (roles.indexOf('drums') >= 0) return true;
    return spec.genres.some(function (g) { return g in C.kit.genres; });
  }
  function choose_parts(requested, spec) {
    if (!requested.length) return C.PITCHED_PARTS.slice();
    var parts = requested.filter(function (v) { return v in C.VOICE_PARTS; }).map(function (v) { return C.VOICE_PARTS[v]; });
    if (parts.indexOf('countermelody') >= 0 && parts.indexOf('melody') < 0) parts.unshift('melody');
    if (parts.length === 1 && parts[0] !== 'bass' && parts[0] !== 'harmony') parts.push('bass');
    var ordered = C.PITCHED_PARTS.filter(function (p) { return parts.indexOf(p) >= 0; });
    return ordered.length ? ordered : C.PITCHED_PARTS.slice();
  }
  function choose_listed_progression(rng, priors, spec) {
    var minor_mode = spec.is_minor;
    var dflt = MODE_DEFAULT_PROGRESSIONS[spec.mode] || (minor_mode ? ['i', 'bVI', 'bIII', 'bVII'] : ['I', 'V', 'vi', 'IV']);
    var ambivalent = C.BLUES_MODES.has(spec.mode);
    var candidates = priors.progressions.filter(function (cw) { return cw[1] > 0 && (ambivalent || progression_is_minor(cw[0]) === minor_mode); });
    candidates.push([dflt, 1.0]);
    var scored = candidates.map(function (cw) { return [cw[0], cw[1], progression_fit(cw[0], spec)]; });
    var found = false;
    [0.999, 0.85].some(function (th) {
      var tier = scored.filter(function (s) { return s[2] >= th; }).map(function (s) { return [s[0], s[1]]; });
      if (tier.length) { candidates = tier; found = true; return true; }
      return false;
    });
    if (!found) return dflt;
    var total = P.sum(candidates.map(function (c) { return c[1]; })), roll = rng.random() * total;
    for (var i = 0; i < candidates.length; i++) { roll -= candidates[i][1]; if (roll <= 0) return candidates[i][0]; }
    return candidates[candidates.length - 1][0];
  }
  function choose_progression(rng, priors, spec) {
    if (rng.random() < priors.functional) {
      var length = rng.random() < (0.3 + 0.3 * priors.functional) ? 8 : 4;
      var chords = C.generate_progression({ tonic: spec.tonic, mode: spec.mode, length: length, chromaticism: spec.chromaticism,
        sevenths: spec.extensions, rng: rng });
      return [chords.map(function (c) { return c.symbol; }), chords.map(function (c) { return c.display; })];
    }
    var chosen = choose_listed_progression(rng, priors, spec);
    return [chosen.slice(), chosen.slice()];
  }
  function search(re, text) { var m = re.exec(text); return m ? m[0] : null; }

  function parse_prompt(text, seed) {
    var vocab = C.vocabulary;
    var seed_match = SEED_RE.exec(text);
    if ((seed === undefined || seed === null) && seed_match) seed = parseInt(seed_match[1], 10);
    if (seed === undefined || seed === null) seed = 1 + Math.floor(Math.random() * (2147483648 - 1));
    var rng = new R.Random(seed);
    var matches = vocab.find(text);
    var priors = vocab.priors_for(matches);
    var spec = new MusicSpec({ prompt: text.trim(), seed: seed });
    function tagsOf(kind) { return P.unique(matches.filter(function (m) { return m.kind === kind; }).map(function (m) { return m.tag; })); }
    spec.genres = tagsOf('genre'); spec.moods = tagsOf('mood'); spec.descriptors = tagsOf('descriptor');
    spec.scales = tagsOf('scale'); spec.forms = tagsOf('form');
    var requested_voices = tagsOf('voice');
    spec.forms.forEach(function (form) {
      var implied = FORM_IMPLIES_GENRE[form];
      if (implied && !spec.genres.length) {
        spec.genres = [implied];
        priors = vocab.priors_for(matches.concat([new C.Match('genre', implied, implied, 0, 0)]));
      }
    });
    spec.matched_terms = matches.map(function (m) { return m.phrase; });
    var directives = [KEY_RE, BARE_MODE_RE, BPM_RE, AT_TEMPO_RE, METER_RE, BARS_RE, SECONDS_RE, MINUTES_RE, SEED_RE]
      .map(function (re) { return search(re, text); }).filter(function (m) { return m !== null; });
    spec.unmatched_terms = leftover_terms(text, spec.matched_terms, directives);
    var roles = matches.filter(function (m) { return m.kind === 'role'; }).map(function (m) { return m.tag; });

    var meter = extract_meter(text);
    if (meter === null) {
      var mn = pick_weighted(rng, priors.meters, '4/4').split('/');
      meter = [parseInt(mn[0], 10), parseInt(mn[1], 10)];
    }
    spec.meter = meter;
    var k = extract_key(text), tonic = k[0], mode = k[1];
    if (mode === null || !(mode in C.SCALES)) mode = pick_weighted(rng, priors.modes, 'major');
    spec.mode = mode;
    if (tonic === null) tonic = rng.choices([0, 2, 4, 5, 7, 9, 11, 1, 3, 6, 8, 10], [6, 5, 4, 6, 6, 5, 2, 3, 4, 3, 4, 3], 1)[0];
    spec.tonic = tonic;
    spec.tonic_spelling = k[2];
    var tempo = extract_tempo(text);
    if (tempo === null) {
      var lh = [priors.tempo_low, priors.tempo_high].sort(function (a, b) { return a - b; });
      tempo = rng.uniform(lh[0], lh[1]) * priors.tempo_scale;
    }
    spec.tempo = Math.trunc(P.round(tempo));
    var bars_match = BARS_RE.exec(text);
    if (bars_match) spec.bars = parseInt(bars_match[1], 10);
    else {
      var bpb = spec.meter[0] * 4.0 / spec.meter[1], seconds = null;
      if (MINUTES_RE.exec(text)) seconds = parseInt(MINUTES_RE.exec(text)[1], 10) * 60;
      else if (SECONDS_RE.exec(text)) seconds = parseInt(SECONDS_RE.exec(text)[1], 10);
      if (seconds) spec.bars = C.snap_to_ladder(Math.trunc(P.round(seconds * spec.tempo / 60.0 / bpb)));
      else if (spec.scales.length) spec.bars = P.max(spec.scales.map(function (t) { var b = vocab.scales[t].bars; return b === undefined ? 16 : b; }));
      else spec.bars = 16;
    }
    spec.chances = priors.chances;
    spec.chromaticism = Math.max(0.0, Math.min(1.0, priors.chromaticism));
    spec.ornament = Math.max(0.0, Math.min(1.0, priors.ornament));
    spec.density = priors.density; spec.swing = priors.swing; spec.extensions = priors.extensions;
    spec.register = Math.trunc(P.round(priors.register));
    spec.velocity = Math.trunc(P.round(priors.velocity));
    spec.humanize = priors.humanize;
    spec.pattern = pick_weighted(rng, priors.patterns, 'block');
    var cl = choose_progression(rng, priors, spec);
    spec.progression = cl[0].slice(); spec.progression_labels = cl[1].slice();
    if (!bars_match) {
      var cycle = spec.progression.length;
      if (cycle > 8 && spec.bars % cycle) spec.bars = cycle * Math.max(1, P.round(spec.bars / cycle));
    }
    spec.harmony = choose_treatment(requested_voices, spec);
    spec.voices = choose_parts(requested_voices, spec);
    if (wants_drums(text, spec, roles)) spec.voices.push('drums');
    return spec.clamp();
  }

  // ================================================================= render
  var SUFFIXED = /(maj7|maj9|add9|sus2|sus4|m7|o7|[679]|o|0|\+)$/;
  function colour(symbol, rng, extensions) {
    if (SUFFIXED.test(symbol) || rng.random() > extensions) return symbol;
    var acc = 'b#'.indexOf(symbol[0]) >= 0 ? symbol[0] : '';
    var numeral = symbol.slice(acc.length);
    if (P.isupper(numeral)) return symbol + (numeral === 'V' ? '7' : 'maj7');
    return symbol + '7';
  }
  function build_chord_spans(spec, rng) {
    var bpb = spec.beats_per_bar, spans = [];
    var coloured = spec.progression.map(function (s) { return colour(s, rng, spec.extensions); });
    for (var bar = 0; bar < spec.bars; bar++) {
      var chord;
      try { chord = C.parse_roman(coloured[bar % coloured.length], spec.tonic, spec.mode); }
      catch (e) { chord = C.parse_roman(spec.progression[bar % spec.progression.length], spec.tonic, spec.mode); }
      spans.push([bar * bpb, bpb, chord]);
    }
    return spans;
  }
  function chords_by_bar(spans) { return spans.map(function (s) { return [[0.0, s[2]]]; }); }
  function name_chords(spec, spans, labels) {
    var key = spec.key();
    labels = (labels && labels.length) ? labels : (spec.progression_labels.length ? spec.progression_labels : spec.progression);
    return spans.map(function (s, bar) {
      return { bar: bar + 1, beat: P.round(s[0], 4), roman: s[2].symbol, function: labels.length ? labels[bar % labels.length] : s[2].symbol,
        symbol: C.detect_chord(s[2].pitch_classes, s[2].bass, key) || '' };
    });
  }
  function dynamic_arc(spec, notes) {
    if (!notes.length) return;
    var total = P.max(notes.map(function (n) { return n.end; }));
    if (total <= 0) return;
    notes.forEach(function (n) {
      var position = n.start / total;
      var swell = Math.trunc(P.round(10 * (position - 0.5) * 2 * 0.5));
      var intro = position < 0.12 ? -8 : 0, outro = position > 0.92 ? -6 : 0;
      n.velocity = Math.max(1, Math.min(127, n.velocity + swell + intro + outro));
    });
  }
  function humanize_timing(spec, notes, rng) {
    var jitter = 0.012 * spec.humanize;
    if (jitter <= 0) return;
    notes.forEach(function (n) { n.start = Math.max(0.0, n.start + rng.gauss(0, jitter)); });
  }
  var MONOPHONIC_PARTS = ['melody', 'countermelody', 'bass'];
  function keep_monophonic(notes) {
    var ordered = P.sorted(notes, function (n) { return n.start; });
    for (var i = 0; i < ordered.length - 1; i++) {
      var room = ordered[i + 1].start - ordered[i].start;
      if (room > 0) ordered[i].duration = Math.min(ordered[i].duration, room);
    }
  }
  function trim_overlaps(notes) {
    var by = new Map();
    P.sorted(notes, function (n) { return n.start; }).forEach(function (n) {
      var prev = by.get(n.pitch);
      if (prev && prev.end > n.start) prev.duration = Math.max(0.05, n.start - prev.start - 0.01);
      by.set(n.pitch, n);
    });
  }
  function Track(name, channel, role, detail) {
    this.name = name; this.program = 0; this.channel = channel; this.role = role; this.detail = detail; this.notes = []; this.controls = [];
  }
  Track.prototype.to_dict = function () {
    return { name: this.name, program: this.program, channel: this.channel, role: this.role, detail: this.detail,
      notes: this.notes.map(function (n) { return n.to_dict(); }) };
  };
  function extend(track, notes, offset, transpose) {
    notes.forEach(function (n) {
      n.start += offset;
      if (transpose) n.pitch = Math.max(21, Math.min(108, n.pitch + transpose));
      track.notes.push(n);
    });
  }
  function xor(seed, k) { return Number(BigInt(seed) ^ BigInt(k)); }

  function render(spec) {
    var rng = new R.Random(spec.seed);
    var intervals = C.DEFAULT_INTERVALS, rhythm_bias = null;
    function fresh_progression(length, cadence, base) {
      if (base && cadence) {
        return C.recadence(base[0], base[1], spec.tonic, spec.mode, cadence, base[0].some(function (s) { return s.indexOf('7') >= 0; }));
      }
      var chords = C.generate_progression({ tonic: spec.tonic, mode: spec.mode, length: length, chromaticism: spec.chromaticism,
        sevenths: spec.extensions, rng: rng, cadence: cadence });
      return [chords.map(function (c) { return c.symbol; }), chords.map(function (c) { return c.display; })];
    }
    spec.form_name = C.choose_form(spec, new R.Random(spec.seed));
    spec.forms = [spec.form_name];
    var sections = C.plan_form(spec, rng, fresh_progression);
    spec.form = C.describe(sections);
    spec.bars = P.sum(sections.map(function (s) { return s.bars; }));

    var voiced = new Set(spec.voices.length ? spec.voices : C.PITCHED_PARTS);
    var treatment = C.TREATMENTS.indexOf(spec.harmony) >= 0 ? spec.harmony : 'chords';
    var beat = voiced.has('drums') ? C.pattern_for(spec, new R.Random(xor(spec.seed, 0x0D2D5))) : null;
    var tracks = {};
    C.PARTS.forEach(function (part) {
      tracks[part] = new Track(C.PART_NAMES[part], C.PART_CHANNELS[part], part,
        part === 'harmony' ? treatment : (part === 'drums' && beat ? beat.label : ''));
    });
    var ostinato_figure = treatment === 'ostinato' ? C.make_ostinato_figure(spec, new R.Random(xor(spec.seed, 0x05713))) : null;
    var bpb = spec.beats_per_bar, all_spans = [], all_labels = [], ornaments = [];
    function shifted(list, offset) { return list.map(function (e) { return new C.Embellishment(e.kind, e.beat + offset, e.pitch); }); }

    sections.forEach(function (section) {
      var part = spec.replace({ bars: section.bars, density: section.density, register: section.register, velocity: section.velocity,
        pattern: section.pattern, progression: section.progression.slice(), progression_labels: section.progression_labels.slice() }).clamp();
      var motif_rng = new R.Random(spec.seed + ':' + section.letter);
      var spans = build_chord_spans(part, rng);
      var offset = section.start_bar * bpb;
      var melody = [], e;
      if (voiced.has('melody')) {
        melody = C.generate_melody(part, chords_by_bar(spans), rng, { intervals: intervals, rhythm_bias: rhythm_bias, motif_rng: motif_rng, cadence: section.cadence });
        e = C.embellish(part, spans, melody, rng);
        melody = e[0]; ornaments = ornaments.concat(shifted(e[1], offset));
      }
      if (voiced.has('countermelody')) {
        var against = melody.length ? melody : C.generate_melody(part, chords_by_bar(spans), new R.Random(spec.seed),
          { intervals: intervals, motif_rng: motif_rng, cadence: section.cadence });
        var counter = C.generate_countermelody(part, spans, against, rng);
        e = C.embellish(part, spans, counter, rng, part.ornament * 0.6);
        counter = e[0]; ornaments = ornaments.concat(shifted(e[1], offset));
        extend(tracks.countermelody, counter, offset);
      }
      if (voiced.has('melody')) extend(tracks.melody, melody, offset, section.transpose);
      if (voiced.has('harmony')) {
        var harmony = treatment === 'ostinato' ? C.generate_ostinato(part, spans, rng, ostinato_figure)
          : treatment === 'arpeggio' ? C.generate_arpeggio(part, spans, rng) : C.generate_accompaniment(part, spans, rng);
        extend(tracks.harmony, harmony, offset);
      }
      if (voiced.has('bass')) extend(tracks.bass, C.generate_bass(part, spans, rng), offset);
      if (voiced.has('drums') && beat) extend(tracks.drums, C.generate_drums(part, section.bars, rng, beat), offset);
      spans.forEach(function (s) { all_spans.push([s[0] + offset, s[1], s[2]]); });
      for (var i = 0; i < section.bars; i++) all_labels.push(section.progression_labels[i % section.progression_labels.length]);
    });

    var song_tracks = C.PARTS.map(function (p) { return tracks[p]; });
    song_tracks.forEach(function (track) {
      humanize_timing(spec, track.notes, rng);
      dynamic_arc(spec, track.notes);
      trim_overlaps(track.notes);
      if (MONOPHONIC_PARTS.indexOf(track.role) >= 0) keep_monophonic(track.notes);
      track.notes = P.sorted(track.notes, function (n) { return [n.start, n.pitch]; });
    });
    var length = 0;
    song_tracks.forEach(function (t) { t.notes.forEach(function (n) { length = Math.max(length, n.end); }); });
    var song = { tempo: spec.tempo, meter: [spec.meter[0], spec.meter[1]], ticksPerBeat: spec.ticks_per_beat, key: spec.key_name,
      lengthBeats: P.round(length, 4), tracks: song_tracks.map(function (t) { return t.to_dict(); }) };
    return { spec: spec.to_dict(), song: song, chords: name_chords(spec, all_spans, all_labels),
      sections: sections.map(function (s) { return s.to_dict(); }), embellishments: ornaments.map(function (o) { return o.to_dict(); }),
      summary: spec.summary() };
  }

  /* The vocabulary and the kit, from data/vocab/. */
  C.load = function (tags, drums) {
    C.vocabulary = new C.Vocabulary(tags);
    C.kit = drums;
  };
  /* What `python3 -m middaw --json --seed N -- prompt` prints, as an object. */
  C.compose = function (prompt, seed) { return render(parse_prompt(prompt, seed)); };
  Object.assign(C, { MusicSpec: MusicSpec, parse_prompt: parse_prompt, render: render, progression_is_minor: progression_is_minor,
    progression_fit: progression_fit });
})(globalThis.MiddawComposer);
