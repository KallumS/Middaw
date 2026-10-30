/* Generate: music from the family's generators, placed into the song.
 *
 *   Compose         Middaw's own: describe it in words, get a whole sketch
 *   Generate Notes  Good Idea: a motif, a phrase, a measure or a groove
 *   Suggest Notes   Midi Suggester: chords under a tune, a tune over chords
 *   Vary Notes      Midi Variator: variations of a clip, never drifting
 *
 * Every setting is the engine's own (through Noterator's adapters). Results
 * are heard with a click, on a piano (Miderator 0043), and go where you
 * chose: bars dragged across tracks are filled exactly once - the tune on
 * the top track, the bass on the bottom, the chords between - and every
 * line is fitted to the instrument it lands on (Miderator 0036, 0040-0042).
 */
(function (MD) {
  'use strict';
  var app = MD.app, M = MD.model, U = MD.ui, E = MD.engines;
  var body, which = 'good-idea', sessions = {}, results = [], chosen = -1, seeds = {}, composed = null, busy = false;
  var openGroups = { Idea: true };
  var LIST = [
    { id: 'compose', name: 'Compose' },
    { id: 'good-idea', name: 'Generate' },
    { id: 'midi-suggester', name: 'Suggest' },
    { id: 'midi-variator', name: 'Vary' }
  ];

  function session(id) {
    if (!sessions[id]) {
      sessions[id] = new E.Session(id);
      sessions[id].useKey(app.project().key);
      seeds[id] = seeds[id] || 1 + Math.floor(Math.random() * 9000);
    }
    return sessions[id];
  }

  // ----------------------------------------------------------- targets ---
  function target() {
    var p = app.project(), bpb = M.beatsPerBar(p), r = app.sel.range;
    if (r && r.trackIds.length) {
      return { trackIds: r.trackIds, start: r.start, length: r.end - r.start, chosen: true };
    }
    var t = app.track();
    var bar = Math.floor(app.caret / bpb + 1e-9) * bpb;
    return { trackIds: t ? [t.id] : [], start: bar, length: 0, chosen: false };
  }
  function sourceClip() {
    var c = app.clip(), t = app.track();
    if (c) return { track: t, clip: c };
    if (!t) return null;
    var at = M.clipAt(t, app.caret);
    return at ? { track: t, clip: at } : null;
  }
  function describeTarget(gen) {
    var p = app.project(), bpb = M.beatsPerBar(p), T = target();
    if (gen && gen.input === 'selection') {
      var s = sourceClip();
      return s ? 'From ' + (s.clip.name ? '“' + s.clip.name + '”' : 'the clip') + ' on ' + s.track.name + ', bar ' + (Math.floor(s.clip.start / bpb) + 1)
               : 'Choose a clip to work from.';
    }
    var names = T.trackIds.map(function (id) { var t = M.track(p, id); return t ? t.name : ''; });
    if (!names.length) return 'Add a track to generate into.';
    if (T.chosen) return 'Into bars ' + (T.start / bpb + 1) + '–' + ((T.start + T.length) / bpb) + ' of ' + names.join(', ');
    return 'At bar ' + (T.start / bpb + 1) + ' of ' + names[0];
  }
  function context(gen) {
    var p = app.project(), bpb = M.beatsPerBar(p), T = target();
    var t = T.trackIds.length ? M.track(p, T.trackIds[0]) : app.track();
    var ctx = { root: p.key.root, scale: p.key.scale, num: p.meter[0], den: p.meter[1], barBeats: bpb, bpm: p.tempo,
                inst: t ? t.instrument : 'pno', catalogueId: t ? t.instrument : 'pno',
                bars: T.chosen ? Math.round(T.length / bpb) : 4, rangeBars: T.chosen ? Math.round(T.length / bpb) : 0,
                selection: { notes: [], beats: 0, drums: false } };
    if (gen && gen.input === 'selection') {
      var s = sourceClip();
      if (s) ctx.selection = { notes: s.clip.notes.filter(function (n) { return n.start < s.clip.length; }).map(function (n) { return { start: n.start, len: n.len, pitch: n.pitch, vel: n.vel }; }),
                               beats: s.clip.length, drums: !!s.track.drums };
    }
    return ctx;
  }

  // ------------------------------------------------------------ fitting ---
  // A line for a one-note instrument keeps its top note (a bass, its
  // bottom), and the whole line moves by octaves to sit in the range.
  function fitToInstrument(notes, t, role) {
    var inst = MD.roll.instrumentOf(t);
    if (!inst || t.drums) return notes;
    var out = notes.map(function (n) { return { start: n.start, len: n.len, pitch: n.pitch, vel: n.vel }; });
    if (inst.poly === 1) {
      var byStart = {};
      out.forEach(function (n) { var k = Math.round(n.start * 960); (byStart[k] = byStart[k] || []).push(n); });
      out = Object.keys(byStart).map(function (k) {
        var g = byStart[k];
        g.sort(function (a, b) { return b.pitch - a.pitch; });
        return role === 'bass' ? g[g.length - 1] : g[0];
      }).sort(function (a, b) { return a.start - b.start; });
      for (var i = 0; i < out.length - 1; i++) out[i].len = Math.min(out[i].len, out[i + 1].start - out[i].start);
    }
    var best = 0, bestMiss = Infinity;
    for (var oct = -4; oct <= 4; oct++) {
      var miss = 0, sweet = 0;
      out.forEach(function (n) {
        var p = n.pitch + oct * 12;
        if (p < inst.low || p > inst.high) miss += 2;
        else if (inst.sweet && (p < inst.sweet[0] || p > inst.sweet[1])) sweet++;
      });
      var cost = miss * 10 + sweet + Math.abs(oct) * 0.01;
      if (cost < bestMiss) { bestMiss = cost; best = oct; }
    }
    if (best) out.forEach(function (n) { n.pitch += best * 12; });
    return out;
  }
  function roleOf(part) {
    var n = String(part.name || '').toLowerCase();
    if (part.drums) return 'drums';
    if (/bass/.test(n)) return 'bass';
    if (/chord|harmony|pad|comp/.test(n)) return 'chords';
    if (/second|counter/.test(n)) return 'counter';
    return 'melody';
  }

  // Where each part of a result goes, by Miderator's rules.
  function placement(result, T) {
    var p = app.project();
    var tracks = T.trackIds.map(function (id) { return M.track(p, id); }).filter(Boolean);
    var parts = result.parts || [];
    var plan = [];
    if (!tracks.length) return plan;
    if (tracks.length === 1) {
      var notes = [];
      parts.forEach(function (pt) { notes = notes.concat(pt.notes); });
      var single = parts.length === 1 ? roleOf(parts[0]) : 'chords';
      plan.push({ track: tracks[0], notes: parts.length === 1 ? fitToInstrument(notes, tracks[0], single) : notes });
      return plan;
    }
    var drumsTrack = tracks.find(function (t) { return t.drums; });
    var pitched = tracks.filter(function (t) { return !t.drums; });
    var byRole = {};
    parts.forEach(function (pt) { (byRole[roleOf(pt)] = byRole[roleOf(pt)] || []).push(pt); });
    var all = function (list) { var o = []; (list || []).forEach(function (pt) { o = o.concat(pt.notes); }); return o; };
    if (byRole.drums && drumsTrack) plan.push({ track: drumsTrack, notes: all(byRole.drums) });
    if (!pitched.length) return plan;
    var top = pitched[0], bottom = pitched[pitched.length - 1], middle = pitched.slice(1, -1);
    if (byRole.melody) plan.push({ track: top, notes: fitToInstrument(all(byRole.melody), top, 'melody') });
    if (byRole.bass) plan.push({ track: pitched.length > 1 ? bottom : top, notes: fitToInstrument(all(byRole.bass), bottom, 'bass') });
    var chordNotes = all(byRole.chords).concat(all(byRole.counter));
    if (chordNotes.length) {
      var lanes = middle.length ? middle : (byRole.melody ? (pitched.length > 1 && !byRole.bass ? [bottom] : [bottom]) : pitched);
      // each chord's notes spread across the lanes, top note to the top lane
      var groups = {};
      chordNotes.forEach(function (n) { var k = Math.round(n.start * 960); (groups[k] = groups[k] || []).push(n); });
      var perLane = lanes.map(function () { return []; });
      Object.keys(groups).forEach(function (k) {
        var g = groups[k].slice().sort(function (a, b) { return b.pitch - a.pitch; });
        g.forEach(function (n, i) {
          var lane = lanes.length === 1 ? 0 : Math.min(lanes.length - 1, Math.floor(i * lanes.length / g.length));
          perLane[lane].push(n);
        });
      });
      lanes.forEach(function (t, i) {
        var existing = plan.find(function (x) { return x.track.id === t.id; });
        var fitted = fitToInstrument(perLane[i], t, 'chords');
        if (existing) existing.notes = existing.notes.concat(fitted); else plan.push({ track: t, notes: fitted });
      });
    }
    return plan;
  }

  // -------------------------------------------------------------- run ----
  function run(more) {
    if (busy) return;
    var gen = E.gen(which);
    if (gen.input === 'selection' && !sourceClip()) { U.status('Choose a clip first: click one in the tracks.'); return; }
    var s = session(which);
    s.useKey(app.project().key);
    if (more) seeds[which] += 6;
    try {
      var r = s.generate(context(gen), seeds[which], 6);
      results = (r.results || []).filter(function (x) { return x.parts && x.parts.some(function (p) { return p.notes.length; }); });
      chosen = results.length ? 0 : -1;
      U.status(r.message ? String(r.message) : (results.length ? '' : 'Nothing came out of those settings. Try others.'));
      MD.pass.event('discover', 1);
    } catch (e) {
      console.error(e);
      results = []; U.status('The generator stopped: ' + (e.message || e), { warning: true });
    }
    render();
    if (results.length) hear(0);
  }
  function hear(i) {
    var r = results[i];
    if (!r) return;
    chosen = i;
    MD.audio.audition(r.parts, { tempo: app.project().tempo });
    render();
  }

  function insert(mode) {
    var r = results[chosen];
    if (!r) return;
    var gen = E.gen(which), p = app.project(), bpb = M.beatsPerBar(p);
    MD.audio.stopAudition();
    var source = { generator: gen.name, title: r.title };
    var beats = r.beats || Math.max.apply(null, r.parts.map(function (pt) { return pt.notes.reduce(function (m, n) { return Math.max(m, n.start + n.len); }, 0); }));
    beats = Math.ceil(beats / bpb - 1e-6) * bpb;
    if (gen.input === 'selection') return insertFromSelection(gen, r, mode, source, beats);
    if (mode === 'tracks') return insertOnNewTracks(r, source, beats);
    var T = target();
    if (!T.trackIds.length) { insertOnNewTracks(r, source, beats); return; }
    var length = T.chosen ? T.length : beats;
    var plan = placement(r, T);
    var first = null;
    app.commit('Insert ' + gen.name, function (q) {
      plan.forEach(function (pl) {
        var c = M.placeNotes(q, pl.track.id, T.start, length, pl.notes.filter(function (n) { return n.start < length; }), { name: r.title, source: source });
        if (!first) first = { t: pl.track.id, c: c.id };
      });
    });
    if (first) app.selectClip(first.t, first.c);
    if (!T.chosen) app.setCaret(T.start + length);
    U.status('Inserted: ' + r.title, { undo: function () { MD.actions.undo(); } });
    MD.pass.event('idea', 1);
  }

  function insertOnNewTracks(r, source, beats) {
    var p = app.project(), bpb = M.beatsPerBar(p);
    var at = Math.floor(app.caret / bpb + 1e-9) * bpb;
    var made = [];
    app.commit('Insert on New Tracks', function (q) {
      r.parts.forEach(function (pt) {
        if (!pt.notes.length) return;
        var role = roleOf(pt);
        var t = MD.actions.trackForRole(q, role, pt.name);
        q.tracks.push(t);
        M.placeNotes(q, t.id, at, beats, fitToInstrument(pt.notes, t, role), { name: r.title, source: source });
        made.push(t.id);
      });
    });
    if (made[0]) app.selectTrack(made[0]);
    U.status('Inserted on ' + made.length + (made.length === 1 ? ' new track.' : ' new tracks.'), { undo: function () { MD.actions.undo(); } });
    MD.pass.event('idea', 1); MD.pass.event('track', made.length);
  }

  // Suggester's results go beside the clip they came from, Variator's after
  // it (Miderator 0011); neither ever overwrites it, unless asked to.
  function insertFromSelection(gen, r, mode, source, beats) {
    var s = sourceClip();
    if (!s) return;
    var p = app.project();
    if (gen.id === 'midi-suggester') {
      var T = app.sel.range;
      var newId = null, tid = null;
      app.commit('Insert Suggestion', function (q) {
        var src = M.track(q, s.track.id);
        var notes = []; r.parts.forEach(function (pt) { notes = notes.concat(pt.notes); });
        var t = M.newTrack({ name: (r.title || 'Suggestion').slice(0, 40), instrument: src.instrument, sound: M.clone(src.sound), drums: src.drums });
        t.sound.id = M.uid('d');
        var idx = q.tracks.findIndex(function (x) { return x.id === src.id; });
        q.tracks.splice(idx + 1, 0, t);
        newId = M.placeNotes(q, t.id, s.clip.start, s.clip.length, notes, { name: r.title, source: source }).id;
        tid = t.id;
      });
      app.selectClip(tid, newId);
      U.status('The suggestion is on a new track under ' + s.track.name + '.', { undo: function () { MD.actions.undo(); } });
    } else {
      var all = mode === 'all' ? results : [r];
      var at = s.clip.start + s.clip.length, last = null;
      app.commit(mode === 'replace' ? 'Vary in Place' : 'Insert Variations', function (q) {
        all.forEach(function (res) {
          var notes = []; res.parts.forEach(function (pt) { notes = notes.concat(pt.notes); });
          var where = mode === 'replace' ? s.clip.start : at;
          last = M.placeNotes(q, s.track.id, where, s.clip.length, notes, { name: (s.clip.name || 'Variation') + (mode === 'replace' ? '' : ' ′'), source: source });
          if (mode !== 'replace') at += s.clip.length;
        });
      });
      if (last) app.selectClip(s.track.id, last.id);
      U.status(mode === 'replace' ? 'Varied in place.' : (all.length + (all.length === 1 ? ' variation' : ' variations') + ' after the clip.'),
        { undo: function () { MD.actions.undo(); } });
    }
    MD.pass.event('idea', 1);
  }

  // ------------------------------------------------------------ compose --
  function compose(prompt) {
    if (!prompt.trim()) return;
    busy = true; render();
    U.status('Composing…');
    return fetch('/api/compose', { method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ prompt: prompt, seed: seeds.compose || undefined }) })
      .then(function (r) { return r.json().then(function (d) { if (!r.ok) throw new Error(d.error || 'failed'); return d; }); })
      .then(function (d) {
        busy = false;
        composed = d;
        seeds.compose = (d.spec && d.spec.seed) || null;
        results = [{ title: d.summary, detail: (d.chords || []).slice(0, 8).map(function (c) { return c.symbol; }).join(' '),
                     beats: d.song.lengthBeats, compose: true,
                     parts: d.song.tracks.map(function (t) { return { name: t.name, drums: t.role === 'drums', role: t.role, detail: t.detail, notes: t.notes.map(M.asNote) }; }) }];
        chosen = 0;
        U.status(d.spec.unmatched_terms && d.spec.unmatched_terms.length ? 'Not understood yet, so left out: ' + d.spec.unmatched_terms.join(', ') : '');
        render();
        MD.pass.event('discover', 1);
        return d;
      })
      .catch(function (e) {
        busy = false; render();
        U.status('Compose needs Middaw’s server (python3 server/app.py): ' + e.message, { warning: true });
      });
  }
  // A composition becomes the song: its five parts, its key, tempo and meter.
  function insertComposed(asSong) {
    var d = composed;
    if (!d) return;
    MD.audio.stopAudition();
    var p = app.project(), bpb = M.beatsPerBar(p);
    var at = asSong ? 0 : Math.floor(app.caret / bpb + 1e-9) * bpb;
    var made = [];
    app.commit('Compose', function (q) {
      if (asSong) {
        q.tempo = d.spec.tempo; q.meter = d.song.meter.slice(); q.key = MD.actions.keyFromSpec(d.spec);
        q.title = d.spec.prompt ? d.spec.prompt.slice(0, 60) : q.title;
      }
      d.song.tracks.forEach(function (st) {
        if (!st.notes.length) return;
        var role = st.role === 'harmony' ? 'chords' : (st.role === 'countermelody' ? 'counter' : st.role);
        var t = MD.actions.trackForRole(q, role, st.name + (st.detail ? ' (' + st.detail + ')' : ''));
        q.tracks.push(t);
        var len = (d.spec.bars || Math.ceil(d.song.lengthBeats / M.beatsPerBar(q) - 1e-6)) * M.beatsPerBar(q);
        M.placeNotes(q, t.id, at, len, st.notes, { name: d.spec.form_name ? d.spec.form_name.replace(/_/g, ' ').replace(/^./, function (c) { return c.toUpperCase(); }) : 'Composed', source: { generator: 'Compose', title: d.spec.prompt } });
        made.push(t.id);
      });
      q.bars = Math.max(q.bars, Math.ceil(M.endOfMusic(q) / M.beatsPerBar(q)) + 4);
    });
    if (made[0]) app.selectTrack(made[0]);
    U.status('Composed: ' + d.summary, { undo: function () { MD.actions.undo(); } });
    MD.pass.event('idea', 1); MD.pass.event('track', made.length);
  }

  // ----------------------------------------------------------- drawing ---
  function miniRoll(r) {
    var c = U.el('canvas', { 'aria-hidden': 'true' });
    requestAnimationFrame(function () {
      var w = c.clientWidth || 260, h = c.clientHeight || 34, g = U.fit(c, w, h);
      var notes = [], lo = 127, hi = 0, end = 0;
      (r.parts || []).forEach(function (pt) {
        var tune = roleOf(pt) === 'melody' || (r.parts.length === 1 && !pt.drums);
        pt.notes.forEach(function (n) { notes.push({ n: n, tune: tune }); lo = Math.min(lo, n.pitch); hi = Math.max(hi, n.pitch); end = Math.max(end, n.start + n.len); });
      });
      if (!notes.length) return;
      var span = Math.max(12, hi - lo + 2), sx = w / Math.max(1, end), rh = Math.max(1.5, h / span);
      // the tune in the accent, chords and bass grey (Good Idea 0009)
      notes.forEach(function (it) {
        g.fillStyle = it.tune ? U.css('--accent') : U.css('--control');
        g.fillRect(it.n.start * sx, (hi + 1 - it.n.pitch) / span * (h - rh), Math.max(1.5, it.n.len * sx - 1), rh);
      });
    });
    return c;
  }

  function settingRow(s, gen, ses) {
    var current = s.names[s.index - 1];
    var hintFor = function (i) { return (s.hints && s.hints[i + 1]) || s.hint || ''; };
    var setTo = function (i) { ses.set(s.id, i + 1, context(gen)); results = []; chosen = -1; render(); };
    var control;
    if (s.names.length <= 6 && s.names.join('').length < 44) {
      control = U.el('div', { class: 'choices', role: 'radiogroup', 'aria-label': s.label }, s.names.map(function (nm, i) {
        return U.el('button', { type: 'button', role: 'radio', 'aria-checked': String(i === s.index - 1), 'aria-pressed': String(i === s.index - 1),
          title: hintFor(i), onclick: function () { setTo(i); } }, [nm]);
      }));
    } else {
      var sel = U.el('select', { 'aria-label': s.label, title: hintFor(s.index - 1) });
      s.names.forEach(function (nm, i) { sel.appendChild(U.el('option', { value: i, text: nm, selected: i === s.index - 1 || null })); });
      sel.onchange = function () { setTo(Number(sel.value)); };
      control = sel;
    }
    return U.el('div', {}, [U.el('div', { class: 'rowline' }, [U.el('span', { class: 'lbl', text: s.label })].concat(control.tagName === 'SELECT' ? [control] : [])),
      control.tagName === 'SELECT' ? null : control].filter(Boolean));
  }

  function render() {
    if (!body || app.view.itab !== 'generate') return;
    var scroll = body.scrollTop;
    U.clear(body);
    if (!E.isReady()) { body.appendChild(U.el('p', { class: 'note-line', text: 'Loading the generators…' })); return; }
    var pick = U.el('div', { class: 'choices segmented', role: 'tablist', 'aria-label': 'Generator' }, LIST.map(function (g) {
      return U.el('button', { type: 'button', role: 'tab', 'aria-selected': String(g.id === which), onclick: function () { choose(g.id); } }, [g.name]);
    }));
    body.appendChild(U.el('section', { class: 'section' }, [pick]));
    if (which === 'compose') return renderCompose(scroll);
    var gen = E.gen(which), ses = session(which);
    body.appendChild(U.el('p', { class: 'note-line', text: describeTarget(gen) }));
    var settings = ses.settings(context(gen));
    var groups = [], byGroup = {};
    settings.forEach(function (s) {
      var g = s.group || 'Settings';
      if (!byGroup[g]) { byGroup[g] = []; groups.push(g); }
      byGroup[g].push(s);
    });
    groups.forEach(function (g, gi) {
      var open = openGroups[g] !== undefined ? openGroups[g] : gi === 0;
      var summary = byGroup[g].map(function (s) { return s.names[s.index - 1]; }).join(' / ');
      var sec = U.el('section', { class: 'section' }, [U.el('button', { type: 'button', class: 'disclosure', 'aria-expanded': String(open),
        onclick: function () { openGroups[g] = !open; render(); } }, [U.el('span', { text: g }), open ? null : U.el('span', { class: 'summary', text: summary })])]);
      if (open) byGroup[g].forEach(function (s) { sec.appendChild(settingRow(s, gen, ses)); });
      body.appendChild(sec);
    });
    var seedField = U.el('input', { type: 'number', min: 1, max: 99999, value: seeds[which], 'aria-label': 'Idea number' });
    seedField.onchange = function () { seeds[which] = Math.max(1, Math.round(+seedField.value || 1)); };
    body.appendChild(U.el('div', { class: 'rowline' }, [
      U.button('Generate', function () { run(false); }, { class: 'primary' }),
      U.button('More Ideas', function () { run(true); }, { disabled: !results.length || null }),
      U.el('span', { class: 'spacer' }), U.el('label', { class: 'field' }, [U.el('span', { text: 'Idea' }), seedField])
    ]));
    renderResults(gen);
    body.scrollTop = scroll;
  }
  function renderResults(gen) {
    if (!results.length) return;
    var list = U.el('div', { class: 'results', role: 'listbox', 'aria-label': 'Results' });
    results.forEach(function (r, i) {
      list.appendChild(U.el('button', { type: 'button', class: 'result', role: 'option', 'aria-pressed': String(i === chosen), 'aria-selected': String(i === chosen),
        onclick: function () { hear(i); }, ondblclick: function () { chosen = i; insert(); } },
        [U.el('span', { class: 't', text: r.title || 'Result ' + (i + 1) }), r.detail ? U.el('span', { class: 'd', text: String(r.detail).replace(/\n/g, ' ') }) : null, miniRoll(r)]));
    });
    body.appendChild(list);
    var actions = U.el('div', { class: 'rowline' });
    if (gen && gen.id === 'midi-variator') {
      actions.appendChild(U.button('Insert After', function () { insert(); }, { class: 'primary' }));
      actions.appendChild(U.button('Insert All', function () { insert('all'); }, { title: 'Every variation, one after another' }));
      actions.appendChild(U.button('Replace', function () { insert('replace'); }, { title: 'Vary the clip where it is' }));
    } else if (gen && gen.id === 'midi-suggester') {
      actions.appendChild(U.button('Insert on a New Track', function () { insert(); }, { class: 'primary' }));
    } else {
      actions.appendChild(U.button('Insert', function () { insert(); }, { class: 'primary' }));
      var multi = results[chosen] && results[chosen].parts.length > 1;
      actions.appendChild(U.button('Insert on New Tracks', function () { insert('tracks'); }, { disabled: !multi || null, title: 'A track for each part' }));
    }
    actions.appendChild(U.button(MD.audio.auditioning() ? 'Stop' : 'Hear', function () { if (MD.audio.auditioning()) { MD.audio.stopAudition(); render(); } else hear(chosen); }));
    body.appendChild(actions);
  }
  function renderCompose(scroll) {
    var ta = U.el('textarea', { rows: 3, maxlength: 2000, placeholder: 'a celtic jig in D, 16 bars', 'aria-label': 'Describe the music', style: { width: '100%', resize: 'vertical' } });
    ta.value = MD.generate.lastPrompt || '';
    ta.oninput = function () { MD.generate.lastPrompt = ta.value; };
    ta.onkeydown = function (e) { if (e.key === 'Enter' && (e.metaKey || e.ctrlKey)) { e.preventDefault(); compose(ta.value); } };
    body.appendChild(U.el('section', { class: 'section' }, [ta,
      U.el('div', { class: 'rowline' }, [U.button(busy ? 'Composing…' : 'Compose', function () { compose(ta.value); }, { class: 'primary', disabled: busy || null }),
        U.button('Another Take', function () { seeds.compose = null; compose(ta.value); }, { disabled: !composed || busy || null })])]));
    if (results.length && results[0].compose) {
      var r = results[0];
      body.appendChild(U.el('div', { class: 'results' }, [U.el('button', { type: 'button', class: 'result', 'aria-pressed': 'true', onclick: function () { hear(0); } },
        [U.el('span', { class: 't', text: r.title }), U.el('span', { class: 'd', text: r.detail }), miniRoll(r)])]));
      var empty = !app.project().tracks.length;
      body.appendChild(U.el('div', { class: 'rowline' }, [
        U.button(empty ? 'Use as the Song' : 'Add to the Song', function () { insertComposed(empty); }, { class: 'primary' }),
        empty ? null : U.button('Replace the Song', function () { MD.actions.replaceWithComposed(); }),
        U.button(MD.audio.auditioning() ? 'Stop' : 'Hear', function () { if (MD.audio.auditioning()) { MD.audio.stopAudition(); render(); } else hear(0); })
      ].filter(Boolean)));
    }
    body.scrollTop = scroll;
  }

  function choose(id) {
    which = id; results = []; chosen = -1;
    MD.audio.stopAudition();
    render();
  }
  function open(id) {
    if (id) choose(id);
    MD.actions.inspectorTab('generate');
  }

  function init() {
    body = document.getElementById('inspector-body');
    app.on(function (w) { if (app.view.itab === 'generate' && (w.selection || w.all || w.project)) render(); });
  }

  MD.generate = { init: init, render: render, open: open, compose: compose, insertComposed: insertComposed, fitToInstrument: fitToInstrument,
                  composed: function () { return composed; }, lastPrompt: '' };
})(globalThis.MD = globalThis.MD || {});
