/* The parts, ported line for line: middaw/song.py (Note), melody.py,
 * accompaniment.py, voices.py, drums.py and embellish.py. */
(function (C) {
  'use strict';
  var P = globalThis.MiddawPy;

  // =================================================================== song
  function Note(start, duration, pitch, velocity) {
    this.start = start; this.duration = duration; this.pitch = pitch; this.velocity = velocity === undefined ? 80 : velocity;
  }
  Object.defineProperty(Note.prototype, 'end', { get: function () { return this.start + this.duration; } });
  Note.prototype.to_dict = function () {
    return { start: P.round(this.start, 5), duration: P.round(this.duration, 5), pitch: this.pitch, velocity: this.velocity };
  };
  function byStart(a) { return a.start; }

  // ================================================================= melody
  var DEFAULT_INTERVALS = new P.Dict([[-4, 0.6], [-3, 1.2], [-2, 2.4], [-1, 6.0], [0, 1.4], [1, 6.4], [2, 2.6], [3, 1.3],
    [4, 0.7], [5, 0.35], [7, 0.25], [-5, 0.3], [-7, 0.2]]);
  var MOVE_SIZES = { repeat: [0], step: [-1, 1], skip: [-2, 2], leap: [-3, 3, -4, 4, -5, 5, -7, 7] };
  function Motif(rhythm, contour) { this.rhythm = rhythm; this.contour = contour; }

  function weighted_choice(rng, weights) {
    var total = P.sum(weights.values()), roll = rng.random() * total, items = weights.items();
    for (var i = 0; i < items.length; i++) { roll -= items[i][1]; if (roll <= 0) return items[i][0]; }
    return items[0][0];
  }
  function next_move(rng, intervals, chances, previous) {
    var sizes = MOVE_SIZES[chances.move(rng)];
    var weights = new P.Dict(sizes.map(function (s) { return [s, intervals.get(s, 0.0)]; }));
    if (P.sum(weights.values()) <= 0) weights = new P.Dict(sizes.map(function (s) { return [s, 1.0]; }));
    var step = weighted_choice(rng, weights);
    if (Math.abs(previous) >= 3 && step * previous > 0 && rng.random() < chances.leap_turns_back) step = previous > 0 ? -Math.abs(step) : Math.abs(step);
    return step;
  }
  function chord_at_beat(chords, beat) {
    var current = chords[0][1];
    for (var i = 0; i < chords.length; i++) { if (chords[i][0] <= beat + 1e-6) current = chords[i][1]; else break; }
    return current;
  }
  function make_motif(rng, spec, intervals, bias) {
    var rhythm = C.bar_rhythm(rng, spec.meter, spec.density, bias), contour = [], previous = 0;
    for (var i = 0; i < Math.max(0, rhythm.length - 1); i++) { var s = next_move(rng, intervals, spec.chances, previous); contour.push(s); previous = s; }
    return new Motif(rhythm, contour);
  }
  function vary(rng, motif, spec, intervals, strength, bias) {
    var rhythm = motif.rhythm.slice(), contour = motif.contour.slice();
    if (rng.random() < strength * 0.5) {
      rhythm = C.bar_rhythm(rng, spec.meter, spec.density, bias);
      contour = contour.slice(0, Math.max(0, rhythm.length - 1));
    }
    while (contour.length < Math.max(0, rhythm.length - 1)) contour.push(next_move(rng, intervals, spec.chances, contour.length ? contour[contour.length - 1] : 0));
    contour = contour.slice(0, Math.max(0, rhythm.length - 1));
    if (contour.length && rng.random() < strength) {
      var index = rng.randrange(contour.length);
      contour[index] = next_move(rng, intervals, spec.chances, index ? contour[index - 1] : 0);
    }
    if (contour.length && rng.random() < strength * 0.35) contour = contour.map(function (s) { return -s; });
    return new Motif(rhythm, contour);
  }
  function generate_melody(spec, chords_by_bar, rng, o) {
    o = o || {};
    var intervals = o.intervals || DEFAULT_INTERVALS, bias = o.rhythm_bias || null, motif_rng = o.motif_rng || rng;
    var cad = C.cadence_get(o.cadence);
    var wants_tonic = cad ? cad.melody_target === 'tonic' : true;
    var scale = C.scale_pitch_classes(spec.tonic, spec.mode);
    var centre = 60 + spec.register * 3 + 7;
    var tonic_root = centre - P.mod(centre - (spec.tonic + 60), 12);
    var low = centre - 10, high = centre + 16;
    var bpb = spec.beats_per_bar, pulse = C.pulse_length(spec.meter), notes = [];
    var degree = C.nearest_degree(scale, tonic_root, centre), phrase_length = 4;
    var motif = make_motif(motif_rng, spec, intervals, bias), last_leap = 0;
    chords_by_bar.forEach(function (chords, bar_index) {
      var pos = bar_index % phrase_length, bar_motif;
      if (pos === 0) {
        if (bar_index === 0 || rng.random() < spec.chances.new_motif) motif = make_motif(motif_rng, spec, intervals, bias);
        bar_motif = motif;
      } else if (pos === 2) bar_motif = vary(rng, motif, spec, intervals, 0.8, bias);
      else bar_motif = vary(rng, motif, spec, intervals, 0.35, bias);
      var bar_start = bar_index * bpb;
      var is_final_bar = bar_index === chords_by_bar.length - 1;
      var cadence_bar = is_final_bar || pos === 3;
      bar_motif.rhythm.forEach(function (od, index) {
        var onset = od[0], duration = od[1];
        if (index > 0) {
          var step = bar_motif.contour.length ? bar_motif.contour[Math.min(index - 1, bar_motif.contour.length - 1)] : 0;
          if (Math.abs(last_leap) >= 3 && step * last_leap > 0 && rng.random() < spec.chances.leap_turns_back) step = last_leap > 0 ? -Math.abs(step) : Math.abs(step);
          degree += step;
          last_leap = step;
        }
        var pitch = C.degree_to_pitch(scale, tonic_root, degree);
        if (pitch < low) { degree += scale.length; pitch = C.degree_to_pitch(scale, tonic_root, degree); }
        else if (pitch > high) { degree -= scale.length; pitch = C.degree_to_pitch(scale, tonic_root, degree); }
        var beat = bar_start + onset;
        var chord = chord_at_beat(chords, onset);
        var on_strong = Math.abs(P.mod(onset, pulse)) < 1e-6;
        var wants_ct = on_strong || duration >= pulse;
        if (wants_ct && chord.pitch_classes.indexOf(P.mod(pitch, 12)) < 0) {
          pitch = chord.nearest_tone(pitch);
          degree = C.nearest_degree(scale, tonic_root, pitch);
        }
        if (cadence_bar && index === bar_motif.rhythm.length - 1) {
          var target = chord.nearest_tone(pitch);
          if (is_final_bar && wants_tonic) {
            target = pitch + P.mod(spec.tonic - pitch, 12);
            if (target - pitch > 6) target -= 12;
          }
          pitch = target;
          degree = C.nearest_degree(scale, tonic_root, pitch);
          duration = Math.max(duration, pulse);
        }
        var velocity = spec.velocity + (on_strong ? 6 : -4);
        velocity += Math.trunc(rng.gauss(0, 4) * spec.humanize);
        notes.push(new Note(C.apply_swing(beat - bar_start, spec.swing, spec.meter) + bar_start,
          Math.max(0.1, duration * rng.uniform(0.82, 0.98)), Math.max(21, Math.min(108, pitch)), Math.max(1, Math.min(127, velocity))));
      });
    });
    return notes;
  }

  // ========================================================== accompaniment
  function voiced(chord, spec) { var low = 48 + spec.register * 3; return chord.voice(low, low + 22); }
  function note(spec, rng, start, duration, pitch, off) {
    var velocity = spec.velocity + (off || 0) + Math.trunc(rng.gauss(0, 3) * spec.humanize);
    return new Note(start, Math.max(0.08, duration), Math.max(21, Math.min(108, pitch)), Math.max(1, Math.min(127, velocity)));
  }
  function pattern_block(chord, spec, rng, start, length) {
    var pulse = C.pulse_length(spec.meter);
    var hits = Math.max(1, Math.trunc(P.round(length / (pulse * (spec.density > 0.55 ? 1 : 2)))));
    var step = length / hits, notes = [];
    for (var i = 0; i < hits; i++) voiced(chord, spec).forEach(function (p) { notes.push(note(spec, rng, start + i * step, step * 0.92, p, i ? -8 : 0)); });
    return notes;
  }
  function pattern_sustained(chord, spec, rng, start, length) { return voiced(chord, spec).map(function (p) { return note(spec, rng, start, length * 0.99, p, -14); }); }
  function pattern_rolled(chord, spec, rng, start, length) {
    var spread = 0.045;
    return voiced(chord, spec).map(function (p, i) { return note(spec, rng, start + i * spread, length - i * spread, p, -10); });
  }
  function arp_sequence(chord, spec, updown) {
    var tones = voiced(chord, spec);
    tones = tones.concat([tones[0] + 12]);
    if (updown && tones.length > 2) return tones.concat(tones.slice(1, tones.length - 1).reverse());
    return tones;
  }
  function arpeggiate(chord, spec, rng, start, length, updown) {
    var sequence = arp_sequence(chord, spec, updown);
    var step = spec.density > 0.7 ? 0.25 : 0.5;
    if (C.is_compound(spec.meter)) step = 0.5;
    var count = Math.max(1, Math.trunc(P.round(length / step))), notes = [];
    for (var i = 0; i < count; i++) {
      notes.push(note(spec, rng, C.apply_swing(start + i * step, spec.swing, spec.meter), step * 0.95, sequence[i % sequence.length], i % 2 ? -6 : 0));
    }
    return notes;
  }
  function pattern_alberti(chord, spec, rng, start, length) {
    var tones = voiced(chord, spec);
    while (tones.length < 3) tones.push(tones[0] + 12);
    var order = [tones[0], tones[2], tones[1], tones[2]];
    var step = spec.density > 0.65 ? 0.25 : 0.5, count = Math.max(1, Math.trunc(P.round(length / step))), out = [];
    for (var i = 0; i < count; i++) out.push(note(spec, rng, start + i * step, step * 0.95, order[i % 4], i % 2 ? -6 : 0));
    return out;
  }
  function pattern_waltz(chord, spec, rng, start, length) {
    var tones = voiced(chord, spec);
    var notes = [note(spec, rng, start, 0.9, tones[0] - 12, 4)];
    var upper = tones.length > 1 ? tones.slice(1) : tones;
    [1.0, 2.0].forEach(function (b) { if (b < length) upper.forEach(function (p) { notes.push(note(spec, rng, start + b, 0.85, p, -10)); }); });
    return notes;
  }
  function pattern_oompah(chord, spec, rng, start, length) {
    var tones = voiced(chord, spec), upper = tones.length > 1 ? tones.slice(1) : tones;
    var root = tones[0] - 12, fifth = root + 7, notes = [], beat = 0.0, index = 0;
    while (beat < length - 1e-6) {
      notes.push(note(spec, rng, start + beat, 0.45, index % 2 === 0 ? root : fifth, 4));
      if (beat + 0.5 < length) upper.forEach(function (p) { notes.push(note(spec, rng, start + beat + 0.5, 0.4, p, -10)); });
      beat += 1.0; index++;
    }
    if (!notes.length) return pattern_block(chord, spec, rng, start, length);
    return notes;
  }
  function pattern_offbeat(chord, spec, rng, start, length) {
    var tones = voiced(chord, spec), notes = [], position = 0.5;
    while (position < length - 1e-6) {
      tones.forEach(function (p) { notes.push(note(spec, rng, C.apply_swing(start + position, spec.swing, spec.meter), 0.5 * 0.8, p, -6)); });
      position += 1.0;
    }
    if (!notes.length) return pattern_block(chord, spec, rng, start, length);
    return notes;
  }
  function pattern_broken_octave(chord, spec, rng, start, length) {
    var tones = voiced(chord, spec), root = tones[0] - 12, notes = [], position = 0.0, index = 0;
    while (position < length - 1e-6) {
      if (index % 2 === 0) {
        notes.push(note(spec, rng, start + position, 0.9, root, 2));
        notes.push(note(spec, rng, start + position, 0.9, root + 12, -4));
      } else (tones.length > 1 ? tones.slice(1) : tones).forEach(function (p) { notes.push(note(spec, rng, start + position, 0.8, p, -10)); });
      position += 1.0; index++;
    }
    return notes;
  }
  function pattern_ballad(chord, spec, rng, start, length) {
    var tones = voiced(chord, spec);
    var notes = tones.map(function (p, i) { return note(spec, rng, start + i * 0.03, length * 0.98, p, -12); });
    var mid = length / 2;
    if (mid >= 1.0 && tones.length) notes.push(note(spec, rng, start + mid, length / 2, tones[tones.length - 1] + 12, -18));
    return notes;
  }
  function pattern_walking(chord, spec, rng, start, length) {
    var tones = voiced(chord, spec), notes = [], position = 0.0, index = 0;
    while (position < length - 1e-6) { notes.push(note(spec, rng, start + position, 0.95, tones[index % tones.length], -6)); position += 1.0; index++; }
    return notes;
  }
  function pattern_ostinato(chord, spec, rng, start, length) {
    var tones = voiced(chord, spec), figure = tones.length > 2 ? [0, 1, 0, 2] : [0, 1, 0, 1];
    var step = spec.density > 0.7 ? 0.25 : 0.5, count = Math.max(1, Math.trunc(P.round(length / step))), out = [];
    for (var i = 0; i < count; i++) out.push(note(spec, rng, C.apply_swing(start + i * step, spec.swing, spec.meter), step * 0.9, tones[figure[i % figure.length] % tones.length], i % 2 ? -4 : 2));
    return out;
  }
  var PATTERNS = {
    block: pattern_block, sustained: pattern_sustained, rolled: pattern_rolled,
    arpeggio_up: function (c, s, r, st, l) { return arpeggiate(c, s, r, st, l, false); },
    arpeggio_updown: function (c, s, r, st, l) { return arpeggiate(c, s, r, st, l, true); },
    alberti: pattern_alberti, waltz: pattern_waltz, offbeat: pattern_offbeat, broken_octave: pattern_broken_octave,
    ballad: pattern_ballad, walking: pattern_walking, oompah: pattern_oompah, ostinato: pattern_ostinato
  };
  function generate_accompaniment(spec, spans, rng) {
    var handler = PATTERNS[spec.pattern] || pattern_block, notes = [];
    spans.forEach(function (sp) { notes = notes.concat(handler(sp[2], spec, rng, sp[0], sp[1])); });
    return notes;
  }
  function bass_pitch(chord, root_octave, tone) {
    var root = root_octave + P.mod(chord.root - root_octave, 12);
    if (tone === 'root') return root;
    var wanted = { fifth: 7, third: 4 }[tone] || 0;
    var intervals = chord.pitch_classes.map(function (pc) { return P.mod(pc - chord.root, 12); }).sort(function (a, b) { return a - b; });
    var closest = intervals.length ? P.min(intervals, function (i) { return [Math.abs(i - wanted), i]; }) : 0;
    var pitch = root + closest;
    return pitch - root_octave >= 12 ? pitch - 12 : pitch;
  }
  function monophonic_trim(notes) {
    var ordered = P.sorted(notes, byStart);
    for (var i = 0; i < ordered.length - 1; i++) {
      var room = ordered[i + 1].start - ordered[i].start;
      if (room > 0) ordered[i].duration = Math.min(ordered[i].duration, room);
    }
    return ordered.filter(function (n) { return n.duration > 0.02; });
  }
  function generate_bass(spec, spans, rng) {
    var root_octave = 36 + spec.register * 3;
    var walking = (spec.pattern === 'walking' || spec.pattern === 'offbeat') && spec.density > 0.5;
    var notes = [];
    spans.forEach(function (sp, index) {
      var start = sp[0], length = sp[1], chord = sp[2];
      var root = root_octave + P.mod(chord.root - root_octave, 12);
      var closing = index === spans.length - 1;
      var chosen = closing ? root : bass_pitch(chord, root_octave, spec.chances.bass_tone(rng));
      if (spec.pattern === 'waltz') { notes.push(note(spec, rng, start, length * 0.9, chosen, 6)); return; }
      if (walking) {
        var tones = [chosen, root + 7, root + 12, root + 5], position = 0.0, k = 0;
        while (position < length - 1e-6) { notes.push(note(spec, rng, start + position, 0.9, tones[k % tones.length], k === 0 ? 4 : -4)); position += 1.0; k++; }
      } else {
        notes.push(note(spec, rng, start, Math.min(length, length * 0.95), chosen, 6));
        if (length >= 2.0 && spec.density > 0.45 && !closing) {
          var second = bass_pitch(chord, root_octave, spec.chances.bass_tone(rng));
          if (second === chosen) second = chosen === root ? root + 7 : root;
          notes.push(note(spec, rng, start + length / 2, length / 2 * 0.9, second, -6));
        }
      }
    });
    return monophonic_trim(notes);
  }

  // ================================================================= voices
  var PERFECT = [0, 7];
  function melody_at(melody, beat) {
    var current = null;
    for (var i = 0; i < melody.length; i++) {
      var n = melody[i];
      if (n.start <= beat + 1e-6 && beat + 1e-6 < n.end) current = n;
      else if (n.start > beat + 1e-6) break;
    }
    return current;
  }
  function makes_parallel(pc, c, pm, m) {
    if (pc === null || pm === null || m === null) return false;
    if (c === pc || m === pm) return false;
    if ((c - pc) * (m - pm) <= 0) return false;
    var before = Math.abs(pm - pc) % 12, after = Math.abs(m - c) % 12;
    return before === after && PERFECT.indexOf(before) >= 0;
  }
  function generate_countermelody(spec, spans, melody, rng) {
    if (!spans.length) return [];
    melody = P.sorted(melody, byStart);
    var pulse = C.pulse_length(spec.meter), centre = 60 + spec.register * 3 - 2, low = centre - 10, high = centre + 9;
    var notes = [], previous_pitch = null, previous_melody = null;
    var grid = spec.density < 0.55 ? pulse : pulse / 2;
    spans.forEach(function (sp) {
      var start = sp[0], length = sp[1], chord = sp[2];
      var steps = Math.max(1, Math.trunc(P.round(length / grid)));
      var positions = P.range(steps).map(function (i) { return start + i * grid; });
      var free = positions.filter(function (p) { return !melody.some(function (n) { return Math.abs(n.start - p) < grid * 0.4; }); });
      var chosen = free.length >= Math.max(2, P.floordiv(steps, 2)) ? free : positions;
      chosen.forEach(function (beat, index) {
        var end = index + 1 < chosen.length ? chosen[index + 1] : start + length;
        var duration = Math.max(grid * 0.5, end - beat);
        var above = melody_at(melody, beat), mp = above ? above.pitch : null;
        var candidates = [];
        chord.pitch_classes.forEach(function (pc) {
          for (var o = -1; o < 3; o++) {
            var p = low + P.mod(pc - low, 12) + 12 * o;
            if (!(low <= p && p <= high)) continue;
            if (mp !== null && p >= mp - 2) continue;
            candidates.push(p);
          }
        });
        if (!candidates.length) return;
        var pitch = P.min(candidates, function (p) {
          var step = previous_pitch === null ? 0 : Math.abs(p - previous_pitch), contrary = 0;
          if (previous_pitch !== null && mp !== null && previous_melody !== null) {
            var moved = mp - previous_melody, mine = p - previous_pitch;
            contrary = moved * mine < 0 ? -1 : (mine === 0 ? 0 : 1);
          }
          return [makes_parallel(previous_pitch, p, previous_melody, mp), contrary, step, -p];
        });
        notes.push(note(spec, rng, C.apply_swing(beat, spec.swing, spec.meter), duration * 0.94, pitch, -10));
        previous_pitch = pitch;
        if (mp !== null) previous_melody = mp;
      });
    });
    return notes;
  }
  function make_ostinato_figure(spec, rng) {
    var rhythm = C.bar_rhythm(rng, spec.meter, Math.min(0.85, spec.density + 0.2));
    var shapes = [[0, 2, 1, 2], [0, 1, 2, 1], [0, 2, 3, 2], [0, 0, 2, 1], [0, 1, 0, 2], [2, 1, 0, 1]];
    var shape = rng.choice(shapes);
    return rhythm.map(function (od, i) { return [od[0], od[1], shape[i % shape.length]]; });
  }
  function generate_ostinato(spec, spans, rng, figure) {
    figure = (figure && figure.length) ? figure : make_ostinato_figure(spec, rng);
    if (!figure.length) return [];
    var low = 45 + spec.register * 3, notes = [];
    spans.forEach(function (sp) {
      var start = sp[0], length = sp[1], tones = sp[2].voice(low, low + 16);
      if (!tones.length) return;
      figure.forEach(function (f) {
        if (f[0] >= length - 1e-6) return;
        notes.push(note(spec, rng, C.apply_swing(start + f[0], spec.swing, spec.meter), Math.min(f[1], length - f[0]) * 0.9, tones[f[2] % tones.length], -6));
      });
    });
    return notes;
  }
  function generate_arpeggio(spec, spans, rng) {
    var notes = [];
    spans.forEach(function (sp) { notes = notes.concat(arpeggiate(sp[2], spec, rng, sp[0], sp[1], rng.random() < 0.5)); });
    return notes;
  }

  // ================================================================== drums
  var ACCENT = 'X', GHOST = 'o', REST = '.';
  var STROKE_VELOCITY = { X: 1.0, x: 0.74, o: 0.38 };
  var INSTRUMENT_VELOCITY = { kick: 0.75, snare: 0.87, hat: 0.89, pedalhat: 0.84, openhat: 1.09, ride: 0.92, bell: 1.17, crash: 0.99,
    splash: 1.21, tom: 1.12, hitom: 1.23, lowtom: 1.12, rim: 0.76, clap: 0.87, shaker: 0.70, cowbell: 0.90, conga: 0.80, hiconga: 0.80,
    clave: 0.85, tambourine: 0.70, woodblock: 0.85, timbale: 0.95, agogo: 0.85, cabasa: 0.70, maraca: 0.70, triangle: 0.75 };
  var OFF_BEAT = 0.78, TIMING_SPREAD = 0.19;
  function Pattern(name, entry) {
    this.name = name; this.steps = entry.steps === undefined ? 16 : entry.steps;
    this.lines = P.items(entry).filter(function (kv) { return ['steps', 'meters', 'label'].indexOf(kv[0]) < 0; });
    this.meters = entry.meters || ['4/4']; this.label = entry.label === undefined ? name : entry.label;
  }
  function patterns() { var o = {}; P.items(C.kit.patterns).forEach(function (kv) { o[kv[0]] = new Pattern(kv[0], kv[1]); }); return o; }
  function fills() { return P.items(C.kit.fills || {}).map(function (kv) { return new Pattern(kv[0], kv[1]); }); }
  function pattern_for(spec, rng) {
    var library = patterns(), meter = spec.meter[0] + '/' + spec.meter[1];
    var wanted = spec.drum_pattern || '';
    if (library[wanted] && library[wanted].meters.indexOf(meter) >= 0) return library[wanted];
    var weights = new P.Dict();
    spec.genres.forEach(function (genre) {
      P.items(C.kit.genres[genre] || {}).forEach(function (kv) {
        if (library[kv[0]] && library[kv[0]].meters.indexOf(meter) >= 0) weights.set(kv[0], weights.get(kv[0], 0.0) + Number(kv[1]));
      });
    });
    if (!weights.size) {
      var fallback = C.kit.default_by_meter[meter];
      return fallback ? (library[fallback] || null) : null;
    }
    var total = P.sum(weights.values()), roll = rng.random() * total, items = weights.items();
    for (var i = 0; i < items.length; i++) { roll -= items[i][1]; if (roll <= 0) return library[items[i][0]]; }
    return library[items[0][0]];
  }
  function fill_for(pattern, rng) {
    var c = fills().filter(function (f) { return f.meters.some(function (m) { return pattern.meters.indexOf(m) >= 0; }); });
    return c.length ? rng.choice(c) : null;
  }
  function play_bar(spec, pattern, start, step_beats, rng) {
    var notes = [], per_beat = step_beats ? Math.max(1, Math.trunc(P.round(1.0 / step_beats))) : 4;
    pattern.lines.forEach(function (kv) {
      var instrument = kv[0], line = kv[1], nn = C.kit.kit[instrument];
      if (nn === undefined || nn === null) return;
      var loud = INSTRUMENT_VELOCITY[instrument] !== undefined ? INSTRUMENT_VELOCITY[instrument] : 0.8;
      Array.from(line.slice(0, pattern.steps)).forEach(function (stroke, index) {
        if (stroke === REST || !(stroke in STROKE_VELOCITY)) return;
        if (stroke === GHOST && rng.random() > spec.chances.ghost_note) return;
        var beat = start + index * step_beats;
        beat = start + C.apply_swing(beat - start, spec.swing, spec.meter);
        beat += rng.gauss(0, TIMING_SPREAD) * step_beats * spec.humanize;
        var on_beat = index % per_beat === 0;
        var velocity = spec.velocity * loud * STROKE_VELOCITY[stroke];
        velocity *= on_beat ? 1.0 : OFF_BEAT;
        velocity += rng.gauss(0, 4) * spec.humanize;
        notes.push(new Note(Math.max(0.0, P.round(beat, 5)), 0.12, nn, Math.max(1, Math.min(127, Math.trunc(P.round(velocity))))));
      });
    });
    return P.sorted(notes, function (n) { return [n.start, n.pitch]; });
  }
  function generate_drums(spec, bars, rng, pattern, phrase) {
    phrase = phrase || 4;
    pattern = pattern || pattern_for(spec, rng);
    if (!pattern || !pattern.lines.length) return [];
    var bpb = spec.beats_per_bar, step_beats = bpb / pattern.steps, notes = [];
    for (var bar = 0; bar < bars; bar++) {
      var playing = pattern;
      var closing = (bar + 1) % phrase === 0 && bar + 1 < bars;
      if (closing && rng.random() < spec.chances.drum_fill) playing = fill_for(pattern, rng) || pattern;
      notes = notes.concat(play_bar(spec, playing, bar * bpb, step_beats, rng));
    }
    return notes;
  }

  // ============================================================== embellish
  var PASSING = 'passing', NEIGHBOR = 'neighbor', APPOGGIATURA = 'appoggiatura', ESCAPE = 'escape',
    ANTICIPATION = 'anticipation', SUSPENSION = 'suspension', RETARDATION = 'retardation', LEAP = 3;
  var WEIGHTS = { passing: 4.0, neighbor: 3.0, escape: 1.5, appoggiatura: 1.2 };
  function Embellishment(kind, beat, pitch) { this.kind = kind; this.beat = beat; this.pitch = pitch; }
  Embellishment.prototype.to_dict = function () { return { kind: this.kind, beat: P.round(this.beat, 4), pitch: this.pitch }; };
  function classify(approach, departure) {
    if (approach === null || departure === null) return null;
    if (approach === 0) {
      if (departure < 0 && Math.abs(departure) < LEAP) return SUSPENSION;
      if (departure > 0 && Math.abs(departure) < LEAP) return RETARDATION;
      return null;
    }
    if (departure === 0) return Math.abs(approach) < LEAP ? ANTICIPATION : null;
    var si = Math.abs(approach) < LEAP, so = Math.abs(departure) < LEAP, same = approach * departure > 0;
    if (si && so) return same ? PASSING : NEIGHBOR;
    if (!si && so) return APPOGGIATURA;
    if (si && !so && !same) return ESCAPE;
    return null;
  }
  function EKey(spec) { this.scale = C.scale_pitch_classes(spec.tonic, spec.mode); this.root = 48 + P.mod(spec.tonic, 12); }
  EKey.prototype.degree = function (p) { return C.nearest_degree(this.scale, this.root, p); };
  EKey.prototype.pitch = function (d) { return C.degree_to_pitch(this.scale, this.root, d); };
  EKey.prototype.step = function (p, dir) { return this.pitch(this.degree(p) + dir); };
  function span_chord(spans, beat) {
    for (var i = 0; i < spans.length; i++) if (spans[i][0] - 1e-6 <= beat && beat < spans[i][0] + spans[i][1] - 1e-6) return spans[i][2];
    return spans.length ? spans[spans.length - 1][2] : null;
  }
  function is_chord_tone(spans, beat, pitch) { var c = span_chord(spans, beat); return c !== null && c.pitch_classes.indexOf(P.mod(pitch, 12)) >= 0; }
  function sp(n) { return [n.start, n.pitch]; }
  function fkey(start, pitch) { return P.round(start, 4) + '|' + pitch; }
  function mono(line, minimum) {
    var out = [];
    line.forEach(function (n, i) {
      if (i + 1 < line.length) {
        var room = line[i + 1].start - n.start;
        if (room <= 0) return;
        n.duration = Math.min(n.duration, room);
      }
      if (n.duration >= minimum * 0.5) out.push(n);
    });
    return out;
  }
  function verify(spans, line, applied) {
    var order = P.sorted(line, sp), index_of = new Map(), out = [];
    order.forEach(function (n, i) { index_of.set(fkey(n.start, n.pitch), i); });
    applied.forEach(function (item) {
      var kind;
      if (item.kind === SUSPENSION || item.kind === RETARDATION) {
        var held = null, i;
        for (i = 0; i < order.length; i++) if (order[i].pitch === item.pitch && order[i].start < item.beat && item.beat < order[i].end + 1e-6) { held = order[i]; break; }
        if (held === null || is_chord_tone(spans, item.beat, item.pitch)) return;
        var after = null;
        for (i = 0; i < order.length; i++) if (order[i].start >= held.end - 1e-6 && order[i].start > held.start) { after = order[i]; break; }
        if (after === null) return;
        kind = classify(0, after.pitch - item.pitch);
        if (kind === SUSPENSION || kind === RETARDATION) out.push(new Embellishment(kind, item.beat, item.pitch));
        return;
      }
      var position = index_of.get(fkey(item.beat, item.pitch));
      if (position === undefined || position === 0 || position + 1 >= order.length) return;
      kind = classify(item.pitch - order[position - 1].pitch, order[position + 1].pitch - item.pitch);
      if (kind === null) return;
      out.push(new Embellishment(kind, item.beat, item.pitch));
    });
    return out;
  }
  function slot(line, index) {
    var n = line[index];
    if (index + 1 < line.length) return Math.max(n.duration, line[index + 1].start - n.start);
    return n.duration;
  }
  function boundary_pass(spec, spans, key, line, rng, amount, minimum, last_index, applied) {
    var changes = new Set(spans.slice(1).map(function (s) { return P.round(s[0], 4); }));
    var frozen = new Set();
    if (!changes.size) return [line, applied, frozen];
    var count = line.length - 1;
    for (var index = 0; index < count; index++) {
      if (index + 1 >= last_index) break;
      var n = line[index], following = line[index + 1];
      var boundary = P.round(following.start, 4);
      if (!changes.has(boundary)) continue;
      if (rng.random() > amount) continue;
      var interval = following.pitch - n.pitch;
      if (!(0 < Math.abs(interval) && Math.abs(interval) < LEAP)) continue;
      var next_slot = slot(line, index + 1);
      var held = Math.min(next_slot / 2, next_slot - minimum);
      if (held >= minimum && !is_chord_tone(spans, boundary, n.pitch)) {
        var kind = classify(0, interval);
        if (kind === SUSPENSION || kind === RETARDATION) {
          n.duration = (following.start + held) - n.start;
          following.start += held;
          following.duration = Math.max(minimum, following.duration - held);
          frozen.add(fkey(n.start, n.pitch));
          frozen.add(fkey(following.start, following.pitch));
          applied.push(new Embellishment(kind, boundary, n.pitch));
          continue;
        }
      }
      if (!is_chord_tone(spans, n.start, following.pitch)) {
        var own = slot(line, index), early = Math.min(own / 2, own - minimum);
        if (early >= minimum) {
          var begins = following.start - early;
          n.duration = Math.min(n.duration, Math.max(minimum, begins - n.start));
          line.push(new Note(begins, early * 0.9, following.pitch, Math.max(1, n.velocity - 8)));
          frozen.add(fkey(begins, following.pitch));
          frozen.add(fkey(n.start, n.pitch));
          frozen.add(fkey(following.start, following.pitch));
          applied.push(new Embellishment(ANTICIPATION, begins, following.pitch));
        }
      }
    }
    line = P.sorted(line, sp);
    line = mono(line, minimum);
    return [line, verify(spans, line, applied), frozen];
  }
  function candidates_for(key, spans, n, following, previous) {
    var found = [];
    function offer(kind, pitch, accented, from, to) {
      if (!(21 <= pitch && pitch <= 108) || pitch === n.pitch) return;
      var beat = accented ? n.start : n.start + n.duration / 2;
      if (is_chord_tone(spans, beat, pitch)) return;
      if (classify(pitch - from, to - pitch) !== kind) return;
      found.push([kind, pitch, accented]);
    }
    var gap = following.pitch - n.pitch;
    if (0 < Math.abs(gap) && Math.abs(gap) <= 4) {
      var middle = Math.abs(key.degree(following.pitch) - key.degree(n.pitch)) === 2
        ? key.pitch(P.floordiv(key.degree(n.pitch) + key.degree(following.pitch), 2)) : null;
      if (middle !== null) offer(PASSING, middle, false, n.pitch, following.pitch);
    }
    if (gap === 0) [1, -1].forEach(function (d) { offer(NEIGHBOR, key.step(n.pitch, d), false, n.pitch, following.pitch); });
    if (previous !== null) [1, -1].forEach(function (d) { offer(APPOGGIATURA, key.step(n.pitch, d), true, previous.pitch, n.pitch); });
    if (Math.abs(gap) >= LEAP) offer(ESCAPE, key.step(n.pitch, gap > 0 ? -1 : 1), false, n.pitch, following.pitch);
    return found;
  }
  function split_pass(spec, spans, key, line, rng, amount, minimum, applied, frozen) {
    var out = [], blocked = new Set();
    line.forEach(function (n, index) {
      out.push(n);
      if (index + 1 >= line.length) return;
      if (frozen.has(fkey(n.start, n.pitch))) return;
      var following = line[index + 1], sl = slot(line, index);
      if (sl < 2 * minimum) return;
      if (rng.random() > amount) return;
      var previous = out.length > 1 ? out[out.length - 2] : null;
      var cands = candidates_for(key, spans, n, following, previous);
      if (blocked.has(P.round(n.start, 4))) cands = cands.filter(function (c) { return !c[2]; });
      if (!cands.length) return;
      var by = new P.Dict();
      cands.forEach(function (c) { by.setdefault(c[0], []).push(c); });
      var kinds = by.keys();
      var total = P.sum(kinds.map(function (k) { return WEIGHTS[k] !== undefined ? WEIGHTS[k] : 1.0; }));
      var roll = rng.random() * total, chosen = kinds[0];
      for (var i = 0; i < kinds.length; i++) { roll -= (WEIGHTS[kinds[i]] !== undefined ? WEIGHTS[kinds[i]] : 1.0); if (roll <= 0) { chosen = kinds[i]; break; } }
      var pick = rng.choice(by.get(chosen)), kind = pick[0], pitch = pick[1], accented = pick[2];
      var half = sl / 2;
      var sustain = Math.max(0.55, Math.min(1.0, n.duration / sl)) * half;
      if (accented) {
        out[out.length - 1] = new Note(n.start, sustain, pitch, Math.min(127, n.velocity + 4));
        out.push(new Note(n.start + half, sustain, n.pitch, n.velocity));
        applied.push(new Embellishment(kind, n.start, pitch));
      } else {
        out[out.length - 1] = new Note(n.start, sustain, n.pitch, n.velocity);
        out.push(new Note(n.start + half, sustain, pitch, Math.max(1, n.velocity - 6)));
        applied.push(new Embellishment(kind, n.start + half, pitch));
        blocked.add(P.round(following.start, 4));
      }
    });
    return [out, applied];
  }
  function embellish(spec, spans, notes, rng, amount, protect_last) {
    if (protect_last === undefined) protect_last = true;
    if (notes.length < 2 || !spans.length) return [notes, []];
    amount = amount === undefined || amount === null ? spec.ornament : amount;
    if (amount <= 0) return [notes, []];
    var key = new EKey(spec);
    var line = P.sorted(notes.map(function (n) { return new Note(n.start, n.duration, n.pitch, n.velocity); }), byStart);
    var applied = [];
    var pulse = Math.max(0.25, spec.beats_per_bar / Math.max(1, spec.meter[0]));
    var minimum = Math.max(0.11, pulse / 4);
    var last_index = protect_last ? line.length - 1 : line.length;
    var b = boundary_pass(spec, spans, key, line, rng, amount, minimum, last_index, applied);
    line = b[0]; applied = b[1];
    var s = split_pass(spec, spans, key, line, rng, amount, minimum, applied, b[2]);
    line = P.sorted(s[0], sp);
    line = mono(line, minimum);
    return [line, verify(spans, line, s[1])];
  }

  Object.assign(C, {
    Note: Note, DEFAULT_INTERVALS: DEFAULT_INTERVALS, generate_melody: generate_melody, generate_accompaniment: generate_accompaniment,
    generate_bass: generate_bass, generate_countermelody: generate_countermelody, make_ostinato_figure: make_ostinato_figure,
    generate_ostinato: generate_ostinato, generate_arpeggio: generate_arpeggio, pattern_for: pattern_for, generate_drums: generate_drums,
    embellish: embellish, Embellishment: Embellishment
  });
})(globalThis.MiddawComposer);
