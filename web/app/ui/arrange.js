/* The arrange view: every track along time, its clips drawn small.
 *
 * Click a clip to open it in the editor below; drag it to move it, its end
 * to stretch it, Alt to copy it. Drag across empty bars - over one track or
 * several - to choose where generated music goes. The ruler sets the caret
 * on a click and the loop on a drag; under it, the chords as they sound,
 * named by ScaleView's reader.
 */
(function (MD) {
  'use strict';
  var app = MD.app, M = MD.model, U = MD.ui;
  var heads, ruler, timeline, wrap, body;
  var drag = null, hover = null;
  var chordCache = { key: null, list: [] };

  function px(beat) { return (beat - app.view.scrollX) * app.view.pxPerBeat; }
  function beatAt(x) { return x / app.view.pxPerBeat + app.view.scrollX; }
  function trackH() { return Math.round(4.4 * U.rem()); }
  function visibleBeats() { return timeline.clientWidth / app.view.pxPerBeat; }
  function songBeats() {
    var p = app.project();
    return Math.max(p.bars * M.beatsPerBar(p), M.endOfMusic(p) + 8 * M.beatsPerBar(p));
  }
  // The arrange snaps to bars when zoomed out, to beats when in.
  function arrangeGrid() {
    var p = app.project();
    return app.view.pxPerBeat < 14 ? M.beatsPerBar(p) : 1;
  }

  // -------------------------------------------------------------- heads ---
  function renderHeads() {
    var p = app.project();
    U.clear(heads);
    p.tracks.forEach(function (t) {
      var sel = t.id === app.sel.trackId;
      var dev = MD.devices.DEVICES[t.sound && t.sound.device] || {};
      var soundName = dev.name || '';
      if (t.sound && t.sound.device === 'synth') soundName = MD.synthName(t.sound.preset);
      if (t.sound && t.sound.device === 'creator' && t.sound.presetName) soundName = t.sound.presetName;
      var head = U.el('div', { class: 'track-head' + (sel ? ' selected' : ''), 'data-id': t.id, role: 'button', tabindex: '-1',
        'aria-label': t.name + (sel ? ', selected' : ''),
        onmousedown: function (e) { if (e.target.tagName !== 'BUTTON') { app.selectTrack(t.id); } },
        ondblclick: function (e) { if (e.target.classList.contains('name')) rename(t); },
        oncontextmenu: function (e) { e.preventDefault(); app.selectTrack(t.id); trackMenu(t, e.clientX, e.clientY); } }, [
        U.el('div', { class: 'name', text: t.name, title: 'Double-click to rename' }),
        U.el('div', { class: 'row' }, [
          U.toggle('M', t.mute, function () { app.commit(t.mute ? 'Unmute' : 'Mute', function (q) { var x = M.track(q, t.id); x.mute = !x.mute; }); },
            { title: 'Mute', 'aria-label': 'Mute ' + t.name }),
          U.toggle('S', t.solo, function () { app.commit(t.solo ? 'Unsolo' : 'Solo', function (q) { var x = M.track(q, t.id); x.solo = !x.solo; }); },
            { title: 'Solo', 'aria-label': 'Solo ' + t.name }),
          U.toggle('●', t.arm, function () { app.commit(t.arm ? 'Disarm' : 'Arm for Recording', function (q) { q.tracks.forEach(function (x) { if (x.id === t.id) x.arm = !x.arm; }); }); },
            { title: 'Arm for recording from a MIDI keyboard', 'aria-label': 'Arm ' + t.name }),
          U.el('span', { class: 'sound', text: soundName })
        ])
      ]);
      heads.appendChild(head);
    });
  }
  function rename(t) {
    var name = prompt('Track name', t.name);
    if (name && name.trim()) app.commit('Rename Track', function (q) { M.track(q, t.id).name = name.trim(); });
  }
  function trackMenu(t, x, y) {
    U.menu(null, [
      { label: 'Rename…', action: function () { rename(t); } },
      { label: 'Duplicate Track', action: function () { MD.actions.duplicateTrack(t.id); } },
      { label: 'Delete Track', action: function () { MD.actions.deleteTrack(t.id); } },
      { separator: true },
      { label: 'Generate Here…', action: function () { MD.generate.open(); } }
    ], { x: x, y: y });
  }

  // ------------------------------------------------------------- chords ---
  // The chords lane: what sounds on each beat, named by ScaleView's reader;
  // only real harmony (three notes or more) is named (Miderator 0014).
  function chords() {
    var p = app.project();
    var key = JSON.stringify([p.key, p.tracks.map(function (t) { return t.drums ? 0 : t.clips; })]);
    if (chordCache.key === key) return chordCache.list;
    // The harmony is what the accompaniment plays; a tune's passing notes are
    // not chord tones. With no accompaniment, everything counts.
    var notes = [], pitched = p.tracks.filter(function (t) { return !t.drums && !t.mute; });
    var under = pitched.filter(function (t) { return t.role !== 'melody' && t.role !== 'counter'; });
    (under.length && under.length < pitched.length ? under : pitched).forEach(function (t) { notes = notes.concat(M.trackNotes(t)); });
    var out = [];
    if (notes.length && MD.engines.isReady()) {
      var end = M.endOfMusic(p), bpb = M.beatsPerBar(p);
      var step = bpb % 3 === 0 && p.meter[1] === 8 ? 1.5 : 1;
      for (var b = 0; b < end; b += step) {
        var pcs = {}, pitches = [];
        notes.forEach(function (n) {
          var overlap = Math.min(n.start + n.len, b + step) - Math.max(n.start, b);
          if (overlap >= step * 0.5 - 1e-6 || (Math.abs(n.start - b) < 1e-6 && overlap > 0)) { pitches.push(n.pitch); pcs[n.pitch % 12] = 1; }
        });
        var name = Object.keys(pcs).length >= 3 ? MD.engines.nameChord(pitches, p.key) : '';
        var last = out[out.length - 1];
        if (last && last.name === name) last.end = b + step;
        else out.push({ start: b, end: b + step, name: name, pitches: pitches });
      }
    }
    chordCache = { key: key, list: out.filter(function (c) { return c.name; }) };
    return chordCache.list;
  }
  function chordAt(beat) {
    var list = chords();
    for (var i = 0; i < list.length; i++) if (beat >= list[i].start && beat < list[i].end) return list[i];
    return null;
  }

  // -------------------------------------------------------------- ruler ---
  function drawRuler() {
    var p = app.project();
    var w = ruler.clientWidth, h = ruler.clientHeight;
    var g = U.fit(ruler, w, h);
    g.fillStyle = U.css('--ground'); g.fillRect(0, 0, w, h);
    var bpb = M.beatsPerBar(p), pxb = app.view.pxPerBeat;
    var half = Math.round(h * 0.5);
    if (p.loop && (p.loop.end > p.loop.start)) {
      var lx1 = px(p.loop.start), lx2 = px(p.loop.end);
      g.fillStyle = p.loop.on ? 'rgba(255,242,0,0.28)' : 'rgba(169,175,186,0.18)';
      g.fillRect(lx1, 2, lx2 - lx1, half - 4);
      if (p.loop.on) { g.fillStyle = U.css('--accent'); g.fillRect(lx1, half - 4, lx2 - lx1, 2); }
    }
    var every = pxb * bpb < 28 ? (pxb * bpb < 10 ? 8 : 4) : 1;
    g.font = '600 ' + Math.round(0.92 * U.rem()) + 'px -apple-system, system-ui, sans-serif';
    g.textBaseline = 'middle';
    var first = Math.floor(app.view.scrollX / bpb), last = Math.ceil((app.view.scrollX + w / pxb) / bpb);
    for (var b = first; b <= last; b++) {
      var x = px(b * bpb);
      g.fillStyle = U.css('--rule');
      g.fillRect(Math.round(x), 0, 1, h);
      if (b % every === 0) { g.fillStyle = U.css('--label'); g.fillText(String(b + 1), x + 4, half / 2 + 1); }
    }
    g.fillStyle = U.css('--rule'); g.fillRect(0, half, w, 1);
    // chords lane
    g.font = Math.round(0.92 * U.rem()) + 'px -apple-system, system-ui, sans-serif';
    chords().forEach(function (c) {
      var x1 = px(c.start), x2 = px(c.end);
      if (x2 < 0 || x1 > w) return;
      g.fillStyle = U.css('--raised');
      g.fillRect(x1 + 1, half + 3, Math.max(1, x2 - x1 - 2), h - half - 6);
      g.fillStyle = U.css('--text');
      if (g.measureText(c.name).width <= x2 - x1 - 8) g.fillText(c.name, x1 + 5, half + (h - half) / 2);
    });
    // caret and playhead
    var cx = px(app.caret);
    g.fillStyle = U.css('--accent'); g.beginPath(); g.moveTo(cx - 5, 0); g.lineTo(cx + 5, 0); g.lineTo(cx, 7); g.fill();
    if (MD.audio.isPlaying()) { var ph = px(MD.audio.position()); g.fillStyle = U.css('--playhead'); g.fillRect(ph, 0, 2, h); }
  }

  // ----------------------------------------------------------- timeline ---
  function drawTimeline() {
    var p = app.project();
    var w = wrap.clientWidth, th = trackH();
    var h = Math.max(body.clientHeight, p.tracks.length * th);
    var g = U.fit(timeline, w, h);
    g.fillStyle = U.css('--roll'); g.fillRect(0, 0, w, h);
    var bpb = M.beatsPerBar(p), pxb = app.view.pxPerBeat;
    var first = Math.floor(app.view.scrollX), last = Math.ceil(app.view.scrollX + w / pxb);
    for (var b = first; b <= last; b++) {
      var x = Math.round(px(b));
      var isBar = Math.abs(b / bpb - Math.round(b / bpb)) < 1e-9;
      if (!isBar && pxb < 9) continue;
      g.fillStyle = isBar ? U.css('--rule') : U.css('--beat');
      g.fillRect(x, 0, 1, h);
    }
    p.tracks.forEach(function (t, i) {
      var y = i * th;
      if (t.id === app.sel.trackId) { g.fillStyle = 'rgba(42,47,55,0.55)'; g.fillRect(0, y, w, th); }
      g.fillStyle = U.css('--rule'); g.fillRect(0, y + th - 1, w, 1);
      t.clips.forEach(function (c) {
        var moving = drag && drag.kind === 'clip' && drag.clipId === c.id;
        var start = c.start, length = c.length, ty = y;
        if (moving) { start = drag.newStart; length = drag.newLength; ty = drag.newTrackIndex * th; }
        drawClip(g, t, c, px(start), ty + 3, length * pxb, th - 7, c.id === app.sel.clipId, moving && drag.copy);
        if (moving && drag.copy) drawClip(g, t, c, px(c.start), y + 3, c.length * pxb, th - 7, false, false);
      });
    });
    // chosen bars
    var r = drag && drag.kind === 'range' ? drag.preview : app.sel.range;
    if (r) {
      var x1 = px(r.start), x2 = px(r.end);
      r.trackIds.forEach(function (id) {
        var i = p.tracks.findIndex(function (t) { return t.id === id; });
        if (i < 0) return;
        g.fillStyle = 'rgba(255,242,0,0.16)'; g.fillRect(x1, i * th + 1, x2 - x1, th - 2);
        g.strokeStyle = U.css('--accent'); g.lineWidth = 2; g.strokeRect(x1 + 1, i * th + 2, x2 - x1 - 2, th - 4);
      });
    }
    var cx = Math.round(px(app.caret));
    g.fillStyle = 'rgba(255,242,0,0.55)'; g.fillRect(cx, 0, 1, h);
    if (MD.audio.isPlaying()) { var ph = px(MD.audio.position()); g.fillStyle = U.css('--playhead'); g.fillRect(ph, 0, 2, h); }
  }

  function drawClip(g, t, c, x, y, w, h, selected, ghost) {
    if (x + w < 0 || x > timeline.clientWidth) return;
    g.save();
    g.globalAlpha = ghost ? 0.6 : 1;
    g.fillStyle = U.css('--raised');
    roundRect(g, x + 0.5, y + 0.5, Math.max(3, w - 1), h - 1, 4); g.fill();
    g.strokeStyle = selected ? U.css('--accent') : U.css('--edge');
    g.lineWidth = selected ? 2 : 1; g.stroke();
    g.beginPath(); g.rect(x + 1, y + 1, Math.max(1, w - 2), h - 2); g.clip();
    var label = c.name || (c.source && c.source.title) || '';
    var top = y + 2;
    if (label && h > 30) {
      g.font = Math.round(0.85 * U.rem()) + 'px -apple-system, system-ui, sans-serif';
      g.fillStyle = U.css('--text'); g.textBaseline = 'top';
      g.fillText(label, x + 5, y + 3);
      top = y + 3 + Math.round(1.1 * U.rem());
    }
    if (c.notes.length) {
      var lo = 127, hi = 0;
      c.notes.forEach(function (n) { lo = Math.min(lo, n.pitch); hi = Math.max(hi, n.pitch); });
      lo -= 1; hi += 1;
      var span = Math.max(8, hi - lo), ih = y + h - 3 - top;
      var rowh = Math.max(1, Math.min(4, ih / span));
      g.fillStyle = selected ? U.css('--accent') : U.css('--note');
      c.notes.forEach(function (n) {
        if (n.start >= c.length) return;
        var nx = x + n.start * app.view.pxPerBeat, nw = Math.max(1.5, Math.min(n.len, c.length - n.start) * app.view.pxPerBeat - 1);
        var ny = top + (hi - n.pitch) / span * (ih - rowh);
        g.fillRect(nx, ny, nw, rowh);
      });
    }
    g.restore();
  }
  function roundRect(g, x, y, w, h, r) {
    g.beginPath(); g.moveTo(x + r, y); g.arcTo(x + w, y, x + w, y + h, r); g.arcTo(x + w, y + h, x, y + h, r);
    g.arcTo(x, y + h, x, y, r); g.arcTo(x, y, x + w, y, r); g.closePath();
  }

  // ------------------------------------------------------- hit testing ---
  function hit(x, y) {
    var p = app.project(), th = trackH();
    var ti = Math.floor(y / th);
    var t = p.tracks[ti];
    if (!t) return { trackIndex: ti, beat: beatAt(x) };
    var beat = beatAt(x);
    for (var i = t.clips.length - 1; i >= 0; i--) {
      var c = t.clips[i], x1 = px(c.start), x2 = px(c.start + c.length);
      if (x >= x1 && x <= x2) return { track: t, trackIndex: ti, clip: c, edge: x2 - x < 7 && x2 - x1 > 14, beat: beat };
    }
    return { track: t, trackIndex: ti, beat: beat };
  }

  function onDown(e) {
    if (e.button === 2) return;
    timeline.focus();
    var r = timeline.getBoundingClientRect(), x = e.clientX - r.left, y = e.clientY - r.top;
    var h = hit(x, y), p = app.project();
    if (h.clip) {
      app.selectClip(h.track.id, h.clip.id);
      drag = { kind: 'clip', clipId: h.clip.id, trackId: h.track.id, trackIndex: h.trackIndex, x0: x, y0: y,
               start: h.clip.start, length: h.clip.length, newStart: h.clip.start, newLength: h.clip.length,
               newTrackIndex: h.trackIndex, resize: h.edge, copy: e.altKey, moved: false };
    } else if (h.track) {
      app.selectTrack(h.track.id);
      var g = M.beatsPerBar(p);
      var b = Math.floor(h.beat / g) * g;
      drag = { kind: 'range', x0: x, trackIndex0: h.trackIndex, beat0: h.beat, preview: null, moved: false };
      app.setCaret(M.snap(p, h.beat, arrangeGrid(), 'floor'));
    }
    window.addEventListener('mousemove', onMove);
    window.addEventListener('mouseup', onUp);
  }
  function onMove(e) {
    if (!drag) return;
    var r = timeline.getBoundingClientRect(), x = e.clientX - r.left, y = e.clientY - r.top;
    var p = app.project(), grid = arrangeGrid();
    if (Math.abs(x - drag.x0) > 3 || (drag.y0 !== undefined && Math.abs(y - drag.y0) > 3)) drag.moved = true;
    if (drag.kind === 'clip') {
      var dBeat = (x - drag.x0) / app.view.pxPerBeat;
      if (drag.resize) drag.newLength = Math.max(grid, M.snap(p, drag.start + drag.length + dBeat, grid) - drag.start);
      else {
        drag.newStart = Math.max(0, M.snap(p, drag.start + dBeat, grid));
        drag.newTrackIndex = Math.max(0, Math.min(p.tracks.length - 1, Math.floor(y / trackH())));
      }
    } else if (drag.kind === 'range' && drag.moved) {
      var bpb = M.beatsPerBar(p);
      var b1 = beatAt(x);
      var s = Math.floor(Math.min(drag.beat0, b1) / bpb) * bpb, en = Math.ceil(Math.max(drag.beat0, b1) / bpb + 1e-9) * bpb;
      if (en <= s) en = s + bpb;
      var t1 = Math.max(0, Math.min(p.tracks.length - 1, Math.floor(y / trackH())));
      var lo = Math.min(drag.trackIndex0, t1), hi = Math.max(drag.trackIndex0, t1), ids = [];
      for (var i = lo; i <= hi; i++) if (p.tracks[i]) ids.push(p.tracks[i].id);
      drag.preview = { trackIds: ids, start: s, end: en };
    }
    drawTimeline();
  }
  function onUp() {
    window.removeEventListener('mousemove', onMove);
    window.removeEventListener('mouseup', onUp);
    var d = drag; drag = null;
    if (!d) return;
    var p = app.project();
    if (d.kind === 'clip' && d.moved) {
      var toTrack = p.tracks[d.newTrackIndex];
      if (d.resize) {
        app.commit('Change Clip Length', function (q) { var f = M.clipById(q, d.clipId); f.clip.length = d.newLength; });
      } else {
        var newId = null;
        app.commit(d.copy ? 'Copy Clip' : 'Move Clip', function (q) {
          var f = M.clipById(q, d.clipId), dest = M.track(q, toTrack.id);
          var c = f.clip;
          if (d.copy) { c = M.clone(c); c.id = M.uid('c'); }
          else f.track.clips = f.track.clips.filter(function (x) { return x.id !== d.clipId; });
          c.start = d.newStart;
          M.clearSpan(dest, c.start, c.start + c.length);
          dest.clips.push(c); dest.clips.sort(function (a, b) { return a.start - b.start; });
          newId = c.id;
        });
        if (newId) app.selectClip(toTrack.id, newId);
      }
    } else if (d.kind === 'range') {
      if (d.moved && d.preview) app.chooseRange(d.preview.trackIds, d.preview.start, d.preview.end);
      else { app.sel.range = null; app.sel.clipId = null; app.changed({ selection: true }); }
    }
    app.changed({ view: true });
  }
  function onDouble(e) {
    var r = timeline.getBoundingClientRect(), h = hit(e.clientX - r.left, e.clientY - r.top);
    var p = app.project();
    if (h.clip) { MD.roll.focus(); return; }
    if (!h.track) return;
    var bpb = M.beatsPerBar(p), s = Math.floor(h.beat / bpb) * bpb;
    var id = null;
    app.commit('New Clip', function (q) { id = M.placeNotes(q, h.track.id, s, bpb, [], {}).id; });
    app.selectClip(h.track.id, id);
  }
  function onContext(e) {
    e.preventDefault();
    var r = timeline.getBoundingClientRect(), h = hit(e.clientX - r.left, e.clientY - r.top);
    if (h.clip) { app.selectClip(h.track.id, h.clip.id); MD.actions.clipMenu(e.clientX, e.clientY); }
    else if (h.track) {
      app.selectTrack(h.track.id);
      var inRange = app.sel.range && app.sel.range.trackIds.indexOf(h.track.id) >= 0;
      U.menu(null, [
        { label: inRange ? 'Generate in the Chosen Bars…' : 'Generate Here…', action: function () { if (!inRange) app.setCaret(Math.floor(h.beat / M.beatsPerBar(app.project())) * M.beatsPerBar(app.project())); MD.generate.open(); } },
        { label: 'New Clip', action: function () { onDouble(e); } },
        { label: 'Paste', keys: '⌘V', disabled: !MD.actions.canPaste(), action: function () { MD.actions.paste(); } }
      ], { x: e.clientX, y: e.clientY });
    }
  }
  function onWheel(e) {
    if (e.ctrlKey || e.metaKey) {
      e.preventDefault();
      var r = timeline.getBoundingClientRect(), x = e.clientX - r.left;
      var at = beatAt(x);
      var f = Math.exp(-e.deltaY * 0.004);
      app.view.pxPerBeat = Math.max(2, Math.min(200, app.view.pxPerBeat * f));
      app.view.scrollX = Math.max(0, at - x / app.view.pxPerBeat);
      app.changed({ view: true });
      return;
    }
    var dx = e.shiftKey ? e.deltaY : e.deltaX;
    if (Math.abs(dx) > 0) {
      e.preventDefault();
      app.view.scrollX = Math.max(0, app.view.scrollX + dx / app.view.pxPerBeat);
      app.changed({ view: true });
    }
  }
  function onHover(e) {
    if (drag) return;
    var r = timeline.getBoundingClientRect(), h = hit(e.clientX - r.left, e.clientY - r.top);
    timeline.style.cursor = h.clip ? (h.edge ? 'ew-resize' : 'grab') : 'default';
  }

  // ruler: click sets the caret, drag sets the loop
  function rulerDown(e) {
    var r = ruler.getBoundingClientRect(), x0 = e.clientX - r.left;
    var p = app.project(), b0 = beatAt(x0), moved = false;
    function mv(ev) {
      var x = ev.clientX - r.left;
      if (Math.abs(x - x0) > 3) moved = true;
      if (!moved) return;
      var bpb = M.beatsPerBar(p), g = app.view.pxPerBeat * bpb < 40 ? bpb : 1;
      var a = M.snap(p, Math.min(b0, beatAt(x)), g, 'floor'), b = M.snap(p, Math.max(b0, beatAt(x)), g);
      if (b <= a) b = a + g;
      app.history.project.loop = { on: true, start: a, end: b };
      drawRuler(); drawTimeline();
    }
    function up() {
      window.removeEventListener('mousemove', mv); window.removeEventListener('mouseup', up);
      if (moved) {
        var L = app.history.project.loop;
        app.commit('Set Loop', function (q) { q.loop = { on: true, start: L.start, end: L.end }; });
      } else {
        var beat = M.snap(p, b0, app.view.pxPerBeat < 14 ? M.beatsPerBar(p) : 1, 'floor');
        app.setCaret(beat);
        if (MD.audio.isPlaying()) MD.actions.play(beat);
      }
    }
    window.addEventListener('mousemove', mv); window.addEventListener('mouseup', up);
  }

  // Follow: keep the playhead a third of the way across (Miderator 0034).
  function follow() {
    if (!app.view.follow || !MD.audio.isPlaying()) return;
    var pos = MD.audio.position(), vis = visibleBeats();
    var want = pos - vis / 3;
    if (pos < app.view.scrollX || pos > app.view.scrollX + vis * 0.9 || Math.abs(want - app.view.scrollX) > 0.01) {
      app.view.scrollX = Math.max(0, want);
    }
  }

  function render() {
    var p = app.project();
    document.getElementById('empty').hidden = p.tracks.length > 0;
    drawRuler(); drawTimeline();
  }

  function init() {
    heads = document.getElementById('track-heads');
    ruler = document.getElementById('ruler');
    timeline = document.getElementById('timeline');
    wrap = document.getElementById('timeline-wrap');
    body = document.getElementById('arrange-body');
    timeline.addEventListener('mousedown', onDown);
    timeline.addEventListener('dblclick', onDouble);
    timeline.addEventListener('contextmenu', onContext);
    timeline.addEventListener('wheel', onWheel, { passive: false });
    timeline.addEventListener('mousemove', onHover);
    ruler.addEventListener('mousedown', rulerDown);
    ruler.addEventListener('wheel', onWheel, { passive: false });
    ruler.addEventListener('mousemove', function (e) {
      var r = ruler.getBoundingClientRect(), c = chordAt(beatAt(e.clientX - r.left));
      ruler.title = c ? c.name + ' - click to set the caret, drag to set the loop' : 'Click to set the caret, drag to set the loop';
    });
    app.on(function (w) {
      if (w.all || w.project || w.selection) renderHeads();
      render();
    });
    new ResizeObserver(function () { render(); }).observe(wrap);
  }

  MD.arrange = { init: init, render: render, renderHeads: renderHeads, follow: follow, chordAt: chordAt, songBeats: songBeats, drawRuler: drawRuler, drawTimeline: drawTimeline };
})(globalThis.MD = globalThis.MD || {});
