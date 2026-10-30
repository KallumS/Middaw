/* The project: what Middaw saves, plays and edits.
 *
 * Times are in beats (quarter notes). A key is ScaleView's pair of indices -
 * root 1-18 (C, C#, Db ... Cb) and scale 1-16 (Major ... Dim H-W) - because
 * that is what every family engine reads, so nothing is translated on the way
 * in or out.
 *
 * Every change is a function from one project to the next (Miderator 0005):
 * `commit` keeps the old one for Undo. Nothing about the view - zoom, scroll,
 * the tool - is stored here.
 */
(function (MD) {
  'use strict';

  var SCALE_NAMES = ['Major', 'Minor', 'Harmonic Minor', 'Ionian', 'Dorian', 'Phrygian', 'Lydian',
    'Mixolydian', 'Aeolian', 'Major Pentatonic', 'Minor Pentatonic', 'Major Blues', 'Minor Blues',
    'Whole Tone', 'Diminished W-H', 'Diminished H-W'];
  var SCALE_IV = [[0, 2, 4, 5, 7, 9, 11], [0, 2, 3, 5, 7, 8, 10], [0, 2, 3, 5, 7, 8, 11], [0, 2, 4, 5, 7, 9, 11],
    [0, 2, 3, 5, 7, 9, 10], [0, 1, 3, 5, 7, 8, 10], [0, 2, 4, 6, 7, 9, 11], [0, 2, 4, 5, 7, 9, 10],
    [0, 2, 3, 5, 7, 8, 10], [0, 2, 4, 7, 9], [0, 3, 5, 7, 10], [0, 2, 3, 4, 7, 9], [0, 3, 5, 6, 7, 10],
    [0, 2, 4, 6, 8, 10], [0, 2, 3, 5, 6, 8, 9, 11], [0, 1, 3, 4, 6, 7, 9, 10]];
  var ROOT_NAMES = ['C', 'C#', 'Db', 'D', 'D#', 'Eb', 'E', 'F', 'F#', 'Gb', 'G', 'G#', 'Ab', 'A', 'A#', 'Bb', 'B', 'Cb'];
  var ROOT_PC = [0, 1, 1, 2, 3, 3, 4, 5, 6, 6, 7, 8, 8, 9, 10, 10, 11, 11];

  var nextId = 1;
  function uid(prefix) { return (prefix || 'x') + (nextId++).toString(36) + Math.random().toString(36).slice(2, 6); }

  function clone(o) { return JSON.parse(JSON.stringify(o)); }

  function newProject(opts) {
    opts = opts || {};
    return {
      version: 1,
      title: opts.title || 'Untitled',
      tempo: opts.tempo || 110,
      meter: opts.meter || [4, 4],
      key: opts.key || { root: 1, scale: 1 },
      bars: opts.bars || 32,
      loop: { on: false, start: 0, end: 16 },
      tracks: [],
      returns: [],
      created: Date.now()
    };
  }

  function newTrack(opts) {
    opts = opts || {};
    return {
      id: uid('t'),
      name: opts.name || 'Track',
      instrument: opts.instrument || 'pno',     // the orchestra id: range, clef, playing limits
      role: opts.role || '',                    // melody, countermelody, harmony, bass, drums
      drums: !!opts.drums,
      sound: opts.sound || { device: opts.drums ? 'kit' : 'synth', preset: opts.preset || 'keys' },
      midiFx: opts.midiFx || [],                // [{ id, device, state }]
      audioFx: opts.audioFx || [],
      volume: opts.volume === undefined ? 0.8 : opts.volume,
      pan: opts.pan || 0,
      send: opts.send || 0,                     // to the reverb return
      mute: false, solo: false, arm: false,
      clips: []
    };
  }

  function newClip(opts) {
    opts = opts || {};
    return {
      id: uid('c'),
      name: opts.name || '',
      start: opts.start || 0,
      length: opts.length || 4,
      notes: (opts.notes || []).map(function (n) {
        return { start: n.start, len: n.len, pitch: n.pitch, vel: n.vel === undefined ? 100 : n.vel };
      }),
      cc: opts.cc || {},                       // controller -> [[beat, value], ...]
      source: opts.source || null              // what made it: { generator, title, seed }
    };
  }

  // ------------------------------------------------------------- time ----
  function beatsPerBar(p) { return p.meter[0] * 4 / p.meter[1]; }
  function barOf(p, beat) { return Math.floor(beat / beatsPerBar(p) + 1e-9); }
  function beatToSeconds(p, beat) { return beat * 60 / p.tempo; }
  function secondsToBeat(p, s) { return s * p.tempo / 60; }
  function formatPosition(p, beat) {
    var bpb = beatsPerBar(p), unit = 4 / p.meter[1];
    var bar = Math.floor(beat / bpb + 1e-9);
    var inBar = beat - bar * bpb;
    var b = Math.floor(inBar / unit + 1e-9);
    var sixteenth = Math.floor((inBar - b * unit) / 0.25 + 1e-9);
    return (bar + 1) + '.' + (b + 1) + '.' + (sixteenth + 1);
  }
  // Grid lines count from each bar line (Miderator 0028), not from beat 0.
  function snap(p, beat, grid, mode) {
    if (!grid) return beat;
    var bpb = beatsPerBar(p);
    var bar = Math.floor(beat / bpb + 1e-9) * bpb;
    var off = beat - bar;
    var k = mode === 'floor' ? Math.floor(off / grid + 1e-6) : Math.round(off / grid);
    var r = bar + k * grid;
    return Math.round(r * 960) / 960;
  }

  // ------------------------------------------------------------- keys ----
  function keyInfo(key) {
    var r = key.root || 1, s = key.scale || 1;
    var tonic = ROOT_PC[r - 1];
    var pcs = [];
    for (var i = 0; i < 12; i++) pcs.push(false);
    SCALE_IV[s - 1].forEach(function (iv) { pcs[(tonic + iv) % 12] = true; });
    return { tonic: tonic, pcs: pcs, label: ROOT_NAMES[r - 1] + ' ' + SCALE_NAMES[s - 1],
             rootName: ROOT_NAMES[r - 1], scaleName: SCALE_NAMES[s - 1], intervals: SCALE_IV[s - 1] };
  }

  // ------------------------------------------------------------ lookups --
  function track(p, id) { for (var i = 0; i < p.tracks.length; i++) if (p.tracks[i].id === id) return p.tracks[i]; return null; }
  function clipById(p, id) {
    for (var i = 0; i < p.tracks.length; i++) {
      var t = p.tracks[i];
      for (var j = 0; j < t.clips.length; j++) if (t.clips[j].id === id) return { track: t, clip: t.clips[j] };
    }
    return null;
  }
  function clipAt(t, beat) {
    for (var j = 0; j < t.clips.length; j++) {
      var c = t.clips[j];
      if (beat >= c.start - 1e-9 && beat < c.start + c.length - 1e-9) return c;
    }
    return null;
  }
  // Every note of a track, in song time.
  function trackNotes(t) {
    var out = [];
    t.clips.forEach(function (c) {
      c.notes.forEach(function (n) {
        if (n.start < c.length - 1e-9) out.push({ start: c.start + n.start, len: Math.min(n.len, c.length - n.start), pitch: n.pitch, vel: n.vel, clip: c.id });
      });
    });
    out.sort(function (a, b) { return a.start - b.start || a.pitch - b.pitch; });
    return out;
  }
  function endOfMusic(p) {
    var e = 0;
    p.tracks.forEach(function (t) { t.clips.forEach(function (c) { e = Math.max(e, c.start + c.length); }); });
    return e;
  }

  // ------------------------------------------------------------- edits ---
  // Notes inside a span [start, end) of a track, made into a clip of their own:
  // where a generator's result lands. Clips it overlaps are trimmed or split,
  // so the new music replaces what was there and nothing else (Miderator 0019).
  // A note as Middaw keeps it. The Python side and MIDI files say duration
  // and velocity; the engines and the DAW say len and vel.
  function asNote(n) {
    var len = n.len !== undefined ? n.len : n.duration, vel = n.vel !== undefined ? n.vel : n.velocity;
    return { start: +n.start, len: +len > 0 ? +len : 0.25, pitch: n.pitch | 0, vel: vel === undefined ? 100 : Math.max(1, Math.min(127, Math.round(vel))) };
  }
  function placeNotes(p, trackId, start, length, notes, opts) {
    opts = opts || {};
    var t = track(p, trackId);
    if (!t) return null;
    clearSpan(t, start, start + length);
    var c = newClip({ start: start, length: length, name: opts.name || '', source: opts.source || null,
      notes: notes.map(asNote).filter(function (n) { return n.start < length - 1e-9; }).map(function (n) {
        n.len = Math.max(1 / 64, Math.min(n.len, length - n.start));
        return n;
      }) });
    if (opts.cc) c.cc = opts.cc;
    t.clips.push(c);
    t.clips.sort(function (a, b) { return a.start - b.start; });
    return c;
  }
  function clearSpan(t, s, e) {
    var keep = [];
    t.clips.forEach(function (c) {
      var cs = c.start, ce = c.start + c.length;
      if (ce <= s + 1e-9 || cs >= e - 1e-9) { keep.push(c); return; }
      if (cs < s - 1e-9) {
        var left = clone(c); left.id = uid('c'); left.length = s - cs;
        left.notes = left.notes.filter(function (n) { return n.start < left.length - 1e-9; });
        left.notes.forEach(function (n) { n.len = Math.min(n.len, left.length - n.start); });
        keep.push(left);
      }
      if (ce > e + 1e-9) {
        var right = clone(c); right.id = uid('c'); right.start = e; right.length = ce - e;
        var shift = e - cs;
        right.notes = right.notes.filter(function (n) { return n.start >= shift - 1e-9; })
          .map(function (n) { n.start -= shift; return n; });
        keep.push(right);
      }
    });
    t.clips = keep;
  }
  function splitClip(t, clip, at) {
    if (at <= clip.start + 1e-9 || at >= clip.start + clip.length - 1e-9) return null;
    var right = clone(clip); right.id = uid('c');
    var off = at - clip.start;
    right.start = at; right.length = clip.length - off;
    right.notes = right.notes.filter(function (n) { return n.start >= off - 1e-9; }).map(function (n) { n.start -= off; return n; });
    clip.length = off;
    clip.notes = clip.notes.filter(function (n) { return n.start < off - 1e-9; });
    clip.notes.forEach(function (n) { n.len = Math.min(n.len, off - n.start); });
    t.clips.push(right);
    t.clips.sort(function (a, b) { return a.start - b.start; });
    return right;
  }
  function duplicateClip(t, clip) {
    var c = clone(clip); c.id = uid('c'); c.start = clip.start + clip.length;
    clearSpan(t, c.start, c.start + c.length);
    t.clips.push(c);
    t.clips.sort(function (a, b) { return a.start - b.start; });
    return c;
  }

  // Note edits within a clip.
  function quantize(p, notes, grid, strength) {
    strength = strength === undefined ? 1 : strength;
    notes.forEach(function (n) {
      var target = snap(p, n.start, grid);
      n.start = Math.max(0, n.start + (target - n.start) * strength);
    });
  }
  function transpose(notes, by) {
    notes.forEach(function (n) { n.pitch = Math.max(0, Math.min(127, n.pitch + by)); });
  }
  // Catalogue's and Variator's shapes (Midi Catalogue "Shape It"): the
  // rhythm kept, the contour turned. Done on clip notes in place.
  // Mirrored inside the key, step for step, when the notes are all in it -
  // a chromatic mirror of a tune in C major lands half of it outside C major.
  function invert(notes, key) {
    if (!notes.length) return;
    var info = key ? keyInfo(key) : null;
    var inKey = info && notes.every(function (n) { return info.pcs[n.pitch % 12]; });
    if (inKey) {
      var deg = function (pitch) {               // pitch -> scale steps from C-1
        var oct = Math.floor((pitch - info.tonic) / 12), pc = (pitch - info.tonic) - oct * 12;
        return oct * info.intervals.length + info.intervals.indexOf(pc);
      };
      var pitchOf = function (d) {
        var n = info.intervals.length, oct = Math.floor(d / n);
        return info.tonic + oct * 12 + info.intervals[d - oct * n];
      };
      var ds = notes.map(function (n) { return deg(n.pitch); });
      var axis = Math.max.apply(null, ds) + Math.min.apply(null, ds);
      notes.forEach(function (n, i) { n.pitch = Math.max(0, Math.min(127, pitchOf(axis - ds[i]))); });
      return;
    }
    var hi = Math.max.apply(null, notes.map(function (n) { return n.pitch; }));
    var lo = Math.min.apply(null, notes.map(function (n) { return n.pitch; }));
    notes.forEach(function (n) { n.pitch = hi + lo - n.pitch; });
  }
  function retrograde(notes, length) {
    notes.forEach(function (n) { n.start = Math.max(0, length - n.start - n.len); });
    notes.sort(function (a, b) { return a.start - b.start; });
  }
  function scaleTime(notes, factor) {
    notes.forEach(function (n) { n.start *= factor; n.len *= factor; });
  }
  // Notes outside the key moved to the nearest note that is in it.
  function fitToKey(notes, key) {
    var info = keyInfo(key);
    notes.forEach(function (n) {
      if (info.pcs[n.pitch % 12]) return;
      for (var d = 1; d < 6; d++) {
        if (info.pcs[(n.pitch - d + 120) % 12]) { n.pitch -= d; return; }
        if (info.pcs[(n.pitch + d) % 12]) { n.pitch += d; return; }
      }
    });
  }

  // ------------------------------------------------------------- undo ----
  function History(project) {
    this.project = project;
    this.past = [];
    this.future = [];
    this.listeners = [];
    this.savedAt = 0;
  }
  // `fn` changes a copy; the copy becomes the project, the old one is kept.
  History.prototype.commit = function (label, fn) {
    var before = this.project;
    var next = clone(before);
    var r = fn(next);
    if (r === false) return null;
    this.past.push({ label: label, project: before });
    if (this.past.length > 200) this.past.shift();
    this.future = [];
    this.project = next;
    this.emit({ label: label, kind: 'commit' });
    return r === undefined ? next : r;
  };
  History.prototype.undo = function () {
    var step = this.past.pop();
    if (!step) return null;
    this.future.push({ label: step.label, project: this.project });
    this.project = step.project;
    this.emit({ label: step.label, kind: 'undo' });
    return step.label;
  };
  History.prototype.redo = function () {
    var step = this.future.pop();
    if (!step) return null;
    this.past.push({ label: step.label, project: this.project });
    this.project = step.project;
    this.emit({ label: step.label, kind: 'redo' });
    return step.label;
  };
  History.prototype.replace = function (project, label) {
    this.project = project;
    this.past = []; this.future = [];
    this.emit({ label: label || 'Open', kind: 'replace' });
  };
  History.prototype.on = function (f) { this.listeners.push(f); };
  History.prototype.emit = function (e) { this.listeners.forEach(function (f) { f(e); }); };
  History.prototype.undoLabel = function () { var s = this.past[this.past.length - 1]; return s ? s.label : null; };
  History.prototype.redoLabel = function () { var s = this.future[this.future.length - 1]; return s ? s.label : null; };

  MD.model = {
    SCALE_NAMES: SCALE_NAMES, SCALE_IV: SCALE_IV, ROOT_NAMES: ROOT_NAMES, ROOT_PC: ROOT_PC,
    uid: uid, clone: clone, newProject: newProject, newTrack: newTrack, newClip: newClip,
    beatsPerBar: beatsPerBar, barOf: barOf, beatToSeconds: beatToSeconds, secondsToBeat: secondsToBeat,
    formatPosition: formatPosition, snap: snap, keyInfo: keyInfo,
    track: track, clipById: clipById, clipAt: clipAt, trackNotes: trackNotes, endOfMusic: endOfMusic,
    asNote: asNote, placeNotes: placeNotes, clearSpan: clearSpan, splitClip: splitClip, duplicateClip: duplicateClip,
    quantize: quantize, transpose: transpose, invert: invert, retrograde: retrograde, scaleTime: scaleTime,
    fitToKey: fitToKey, History: History
  };
})(typeof module === 'object' && module.exports
  ? (module.exports = (globalThis.MD = globalThis.MD || {}))
  : (globalThis.MD = globalThis.MD || {}));
