/* The piano roll: the chosen clip's notes, one row per key.
 *
 * Click a note to hear and choose it; drag it to move it, its end to stretch
 * it, Alt to copy; drag empty space to lasso. Double-click (or the Draw tool)
 * adds a note a grid step long. Up and Down move the chosen notes a
 * semitone, Shift an octave. Under the notes, the velocity lane - or a
 * controller lane, drawn by dragging, which AutoCC can fill for you.
 *
 * Beside the keys, the instrument's range: thick where it sounds best. A
 * note it cannot play is marked, and the other tracks show faintly behind.
 */
(function (MD) {
  'use strict';
  var app = MD.app, M = MD.model, U = MD.ui;
  var cv, drag = null, sounding = null;

  function geo() {
    var r = U.rem();
    return { keysW: Math.round(4.6 * r), rulerH: Math.round(1.7 * r), laneH: Math.round(5.6 * r),
             w: cv.parentNode.clientWidth, h: cv.parentNode.clientHeight, rowH: app.view.rowH };
  }
  function clip() { return app.clip(); }
  function px(beat, G) { return G.keysW + (beat - app.view.rollScrollX) * app.view.rollPxPerBeat; }
  function beatAt(x, G) { return (x - G.keysW) / app.view.rollPxPerBeat + app.view.rollScrollX; }
  function py(pitch, G) { return G.rulerH + (app.view.rollTop - pitch) * G.rowH; }
  function pitchAt(y, G) { return Math.round(app.view.rollTop - (y - G.rulerH) / G.rowH + 0.5 - 1e-9); }
  function noteArea(G) { return { top: G.rulerH, bottom: G.h - G.laneH }; }

  function instrumentOf(t) {
    if (!t) return null;
    var list = MD.engines.isReady() ? MD.engines.instruments() : [];
    for (var i = 0; i < list.length; i++) if (list[i].id === t.instrument) return list[i];
    return null;
  }

  // ----------------------------------------------------------- drawing ---
  function draw() {
    if (!cv || cv.offsetParent === null) return;
    var G = geo(), p = app.project(), t = app.track(), c = clip();
    var g = U.fit(cv, G.w, G.h);
    var A = noteArea(G);
    g.fillStyle = U.css('--roll'); g.fillRect(0, 0, G.w, G.h);
    var key = M.keyInfo(p.key), inst = instrumentOf(t);
    var drums = t && t.drums;
    // rows
    var lo = pitchAt(A.bottom, G) - 1, hi = pitchAt(A.top, G) + 1;
    for (var pitch = Math.max(0, lo); pitch <= Math.min(127, hi); pitch++) {
      var y = py(pitch, G);
      if (y > A.bottom || y + G.rowH < A.top) continue;
      var inKey = key.pcs[pitch % 12];
      g.fillStyle = drums ? (pitch % 2 ? '#15181D' : U.css('--roll')) : (inKey ? '#171A20' : U.css('--roll'));
      g.fillRect(G.keysW, y, G.w - G.keysW, G.rowH);
      if (pitch % 12 === 0 || pitch % 12 === 5) { g.fillStyle = U.css('--beat'); g.fillRect(G.keysW, y + G.rowH - 1, G.w - G.keysW, 1); }
      if (inst && !drums && (pitch < inst.low || pitch > inst.high)) {
        g.fillStyle = 'rgba(17,20,25,0.65)'; g.fillRect(G.keysW, y, G.w - G.keysW, G.rowH);
      }
    }
    // grid
    var bpb = M.beatsPerBar(p), grid = app.grid(), pxb = app.view.rollPxPerBeat;
    var first = Math.floor(app.view.rollScrollX / bpb) * bpb, last = app.view.rollScrollX + (G.w - G.keysW) / pxb;
    for (var bar = first; bar <= last; bar += bpb) {
      for (var b = 0; b < bpb - 1e-9; b += grid) {
        var x = Math.round(px(bar + b, G));
        if (x < G.keysW) continue;
        var isBar = b === 0, isBeat = Math.abs(b - Math.round(b)) < 1e-9;
        if (!isBar && !isBeat && grid * pxb < 6) continue;
        g.fillStyle = isBar ? U.css('--rule') : (isBeat ? '#262B33' : U.css('--beat'));
        g.fillRect(x, A.top, 1, A.bottom - A.top);
      }
    }
    // the clip's span; outside it is dimmed
    if (c) {
      var cx1 = px(c.start, G), cx2 = px(c.start + c.length, G);
      g.fillStyle = 'rgba(10,12,15,0.5)';
      if (cx1 > G.keysW) g.fillRect(G.keysW, A.top, cx1 - G.keysW, A.bottom - A.top);
      if (cx2 < G.w) g.fillRect(Math.max(G.keysW, cx2), A.top, G.w - cx2, A.bottom - A.top);
      g.fillStyle = U.css('--edge'); g.fillRect(cx2, A.top, 1, A.bottom - A.top);
    }
    // other tracks, faintly behind
    g.save(); g.beginPath(); g.rect(G.keysW, A.top, G.w - G.keysW, A.bottom - A.top); g.clip();
    p.tracks.forEach(function (o) {
      if (!t || o.id === t.id || o.drums || o.mute) return;
      g.fillStyle = U.css('--note-dim');
      M.trackNotes(o).forEach(function (n) {
        var x1 = px(n.start, G), y1 = py(n.pitch, G);
        if (x1 > G.w || x1 + n.len * pxb < G.keysW || y1 > A.bottom || y1 < A.top - G.rowH) return;
        g.fillRect(x1, y1 + 1, Math.max(2, n.len * pxb - 1), G.rowH - 2);
      });
    });
    // this clip's notes
    if (c) {
      var warn = U.css('--warn');
      notesShown(c).forEach(function (n, i) {
        var x1 = px(c.start + n.start, G), w = Math.max(3, n.len * pxb - 1), y1 = py(n.pitch, G);
        if (x1 > G.w || x1 + w < G.keysW || y1 > A.bottom || y1 < A.top - G.rowH) return;
        var sel = n.sel;
        var a = 0.45 + 0.55 * (n.vel / 127);
        g.globalAlpha = a;
        g.fillStyle = sel ? U.css('--accent') : U.css('--note');
        g.fillRect(x1, y1 + 1, w, G.rowH - 2);
        g.globalAlpha = 1;
        g.strokeStyle = U.css('--ink'); g.lineWidth = 1; g.strokeRect(x1 + 0.5, y1 + 1.5, w - 1, G.rowH - 3);
        if (inst && !drums && (n.pitch < inst.low || n.pitch > inst.high)) {
          g.fillStyle = warn; g.fillRect(x1, y1 + 1, Math.min(w, 4), G.rowH - 2);
        }
      });
    }
    if (drag && drag.kind === 'lasso') {
      g.strokeStyle = U.css('--accent'); g.lineWidth = 1; g.setLineDash([4, 3]);
      g.strokeRect(Math.min(drag.x0, drag.x1), Math.min(drag.y0, drag.y1), Math.abs(drag.x1 - drag.x0), Math.abs(drag.y1 - drag.y0));
      g.setLineDash([]);
    }
    // caret and playhead
    var kx = px(app.caret, G);
    if (kx >= G.keysW) { g.fillStyle = 'rgba(255,242,0,0.55)'; g.fillRect(kx, A.top, 1, A.bottom - A.top); }
    if (MD.audio.isPlaying()) { var ph = px(MD.audio.position(), G); if (ph >= G.keysW) { g.fillStyle = U.css('--playhead'); g.fillRect(ph, 0, 2, G.h); } }
    g.restore();
    drawKeys(g, G, A, inst, drums, t);
    drawRuler(g, G, p);
    drawLane(g, G, c);
    if (!c) {
      g.fillStyle = U.css('--text-dim');
      g.font = Math.round(U.rem()) + 'px -apple-system, system-ui, sans-serif';
      g.textAlign = 'center'; g.textBaseline = 'middle';
      g.fillText(t ? 'Choose a clip, or double-click a track to make one.' : 'Add a track to begin.', (G.w + G.keysW) / 2, (A.top + A.bottom) / 2);
      g.textAlign = 'left';
    }
  }

  // While dragging, the notes as they would be.
  function notesShown(c) {
    var sel = {};
    app.sel.notes.forEach(function (i) { sel[i] = true; });
    if (!drag || (drag.kind !== 'move' && drag.kind !== 'resize')) {
      return c.notes.map(function (n, i) { return { start: n.start, len: n.len, pitch: n.pitch, vel: n.vel, sel: !!sel[i] }; });
    }
    var out = [];
    c.notes.forEach(function (n, i) {
      var s = { start: n.start, len: n.len, pitch: n.pitch, vel: n.vel, sel: !!sel[i] };
      if (sel[i]) {
        if (drag.kind === 'move') {
          if (drag.copy) out.push({ start: n.start, len: n.len, pitch: n.pitch, vel: n.vel, sel: false });
          s.start = Math.max(0, n.start + drag.dBeat); s.pitch = Math.max(0, Math.min(127, n.pitch + drag.dPitch));
        } else s.len = Math.max(1 / 32, n.len + drag.dLen);
      }
      out.push(s);
    });
    return out;
  }

  function drawKeys(g, G, A, inst, drums, t) {
    g.fillStyle = U.css('--ground'); g.fillRect(0, 0, G.keysW, G.h);
    var lo = pitchAt(A.bottom, G) - 1, hi = pitchAt(A.top, G) + 1;
    var black = [1, 3, 6, 8, 10];
    g.font = Math.round(0.78 * U.rem()) + 'px -apple-system, system-ui, sans-serif';
    g.textBaseline = 'middle';
    for (var pitch = Math.max(0, lo); pitch <= Math.min(127, hi); pitch++) {
      var y = py(pitch, G);
      if (y > A.bottom || y + G.rowH < A.top) continue;
      var isBlack = black.indexOf(pitch % 12) >= 0;
      var playing = sounding === pitch;
      g.fillStyle = playing ? U.css('--accent') : (isBlack ? '#3A404A' : '#C0C6CF');
      g.fillRect(G.keysW * 0.32, y, G.keysW * 0.68 - 1, G.rowH - 1);
      if (pitch % 12 === 0 || drums) {
        // named on the key itself, as a keyboard is labelled
        var label = drums ? (DRUM_NAMES[pitch] || '') : 'C' + (pitch / 12 - 1);
        g.fillStyle = isBlack && !playing ? U.css('--text') : U.css('--ink');
        g.textAlign = 'right';
        if (label) g.fillText(label, G.keysW - 4, y + G.rowH / 2);
        g.textAlign = 'left';
      }
    }
    // the range bracket: thin across the range, thick across the sweet spot
    if (inst && !drums) {
      var x = G.keysW * 0.32 - 5;
      var y1 = Math.max(A.top, py(inst.high, G)), y2 = Math.min(A.bottom, py(inst.low, G) + G.rowH);
      g.fillStyle = U.css('--edge'); if (y2 > y1) g.fillRect(x, y1, 2, y2 - y1);
      if (inst.sweet) {
        var s1 = Math.max(A.top, py(inst.sweet[1], G)), s2 = Math.min(A.bottom, py(inst.sweet[0], G) + G.rowH);
        g.fillStyle = U.css('--control'); if (s2 > s1) g.fillRect(x - 2, s1, 4, s2 - s1);
      }
    }
    g.fillStyle = U.css('--rule'); g.fillRect(G.keysW - 1, 0, 1, G.h);
  }
  var DRUM_NAMES = { 35: 'Kick 2', 36: 'Kick', 37: 'Stick', 38: 'Snare', 39: 'Clap', 40: 'Snare 2', 41: 'Tom 6', 42: 'Hat', 43: 'Tom 5',
    44: 'Pedal', 45: 'Tom 4', 46: 'Open', 47: 'Tom 3', 48: 'Tom 2', 49: 'Crash', 50: 'Tom 1', 51: 'Ride', 53: 'Bell', 54: 'Tamb', 56: 'Cowbell', 57: 'Crash 2' };

  function drawRuler(g, G, p) {
    g.fillStyle = U.css('--ground'); g.fillRect(G.keysW, 0, G.w - G.keysW, G.rulerH);
    var bpb = M.beatsPerBar(p), pxb = app.view.rollPxPerBeat;
    g.font = '600 ' + Math.round(0.85 * U.rem()) + 'px -apple-system, system-ui, sans-serif';
    g.textBaseline = 'middle';
    var first = Math.floor(app.view.rollScrollX / bpb), last = Math.ceil((app.view.rollScrollX + (G.w - G.keysW) / pxb) / bpb);
    for (var b = first; b <= last; b++) {
      var x = px(b * bpb, G);
      if (x < G.keysW - 1) continue;
      g.fillStyle = U.css('--rule'); g.fillRect(x, 0, 1, G.rulerH);
      g.fillStyle = U.css('--label'); g.fillText(String(b + 1), x + 4, G.rulerH / 2);
    }
    g.fillStyle = U.css('--rule'); g.fillRect(G.keysW, G.rulerH - 1, G.w - G.keysW, 1);
  }

  function drawLane(g, G, c) {
    var top = G.h - G.laneH;
    g.fillStyle = U.css('--sunken'); g.fillRect(0, top, G.w, G.laneH);
    g.fillStyle = U.css('--rule'); g.fillRect(0, top, G.w, 1);
    g.fillStyle = U.css('--label');
    g.font = Math.round(0.85 * U.rem()) + 'px -apple-system, system-ui, sans-serif';
    g.textBaseline = 'top';
    var lane = app.view.lane;
    g.fillText(lane === 'vel' ? 'Velocity' : 'CC' + lane, 4, top + 4);
    if (!c) return;
    var inner = G.laneH - 8, base = G.h - 4, pxb = app.view.rollPxPerBeat;
    if (lane === 'vel') {
      var sel = {};
      app.sel.notes.forEach(function (i) { sel[i] = true; });
      c.notes.forEach(function (n, i) {
        var x = px(c.start + n.start, G);
        if (x < G.keysW || x > G.w) return;
        var v = drag && drag.kind === 'vel' && drag.vel[i] !== undefined ? drag.vel[i] : n.vel;
        var hgt = v / 127 * inner;
        g.fillStyle = sel[i] ? U.css('--accent') : U.css('--note');
        g.fillRect(x, base - hgt, 3, hgt);
        g.fillRect(x - 2, base - hgt, 7, 2);
      });
    } else {
      var pts = (drag && drag.kind === 'cc' ? drag.points : (c.cc && c.cc[lane])) || [];
      if (!pts.length) return;
      g.strokeStyle = U.css('--note'); g.lineWidth = 2; g.beginPath();
      pts.forEach(function (pt, i) {
        var x = px(c.start + pt[0], G), y = base - pt[1] / 127 * inner;
        if (i === 0) g.moveTo(x, y); else { var prev = pts[i - 1]; g.lineTo(x, base - prev[1] / 127 * inner); g.lineTo(x, y); }
      });
      var lastPt = pts[pts.length - 1];
      g.lineTo(px(c.start + c.length, G), base - lastPt[1] / 127 * inner);
      g.stroke();
    }
  }

  // ------------------------------------------------------------ hitting ---
  function noteAt(x, y, G) {
    var c = clip();
    if (!c) return null;
    var pitch = pitchAt(y, G), beat = beatAt(x, G) - c.start;
    for (var i = c.notes.length - 1; i >= 0; i--) {
      var n = c.notes[i];
      if (n.pitch === pitch && beat >= n.start && beat <= n.start + n.len) {
        var endX = px(c.start + n.start + n.len, G);
        return { index: i, edge: endX - x < 6 && n.len * app.view.rollPxPerBeat > 12 };
      }
    }
    return null;
  }

  function hear(pitch, vel) {
    var t = app.track();
    if (!t || !MD.audio.context()) return;
    if (sounding !== null) MD.audio.live(t.id, [0x80, sounding, 0]);
    sounding = pitch;
    MD.audio.live(t.id, [t.drums ? 0x99 : 0x90, pitch, vel || 100]);
  }
  function hush() {
    var t = app.track();
    if (t && sounding !== null) MD.audio.live(t.id, [0x80, sounding, 0]);
    sounding = null;
  }

  function onDown(e) {
    if (e.button === 2) return;
    cv.focus();
    var G = geo(), r = cv.getBoundingClientRect(), x = e.clientX - r.left, y = e.clientY - r.top;
    var p = app.project(), c = clip(), A = noteArea(G);
    MD.audio.init();
    if (x < G.keysW && y > A.top && y < A.bottom) { hear(pitchAt(y, G)); window.addEventListener('mouseup', function up() { hush(); window.removeEventListener('mouseup', up); }); draw(); return; }
    if (y < G.rulerH) {
      app.setCaret(M.snap(p, beatAt(x, G), app.grid(), 'floor'));
      if (MD.audio.isPlaying()) MD.actions.play(app.caret);
      return;
    }
    if (!c) return;
    if (y > A.bottom) { laneDown(x, y, G, c); return; }
    var hit = noteAt(x, y, G);
    var draw_ = app.view.tool === 'draw';
    if (hit) {
      if (draw_) { app.commit('Delete Note', function (q) { M.clipById(q, c.id).clip.notes.splice(hit.index, 1); }); app.sel.notes = []; return; }
      if (e.shiftKey) {
        var k = app.sel.notes.indexOf(hit.index);
        if (k >= 0) app.sel.notes.splice(k, 1); else app.sel.notes.push(hit.index);
      } else if (app.sel.notes.indexOf(hit.index) < 0) app.sel.notes = [hit.index];
      var n = c.notes[hit.index];
      hear(n.pitch, n.vel);
      drag = { kind: hit.edge ? 'resize' : 'move', x0: x, y0: y, dBeat: 0, dPitch: 0, dLen: 0, copy: e.altKey, moved: false, pitch0: n.pitch };
    } else if (draw_ || e.detail === 2) {
      addNote(x, y, G, c);
      return;
    } else {
      if (!e.shiftKey) app.sel.notes = [];
      drag = { kind: 'lasso', x0: x, y0: y, x1: x, y1: y, add: e.shiftKey ? app.sel.notes.slice() : [] };
      app.setCaret(M.snap(p, beatAt(x, G), app.grid(), 'floor'));
    }
    app.changed({ selection: true });
    window.addEventListener('mousemove', onMove);
    window.addEventListener('mouseup', onUp);
  }

  function addNote(x, y, G, c) {
    var p = app.project();
    var grid = app.grid();
    var beat = M.snap(p, beatAt(x, G), grid, 'floor') - c.start;
    if (beat < 0 || beat >= c.length) return;
    var pitch = pitchAt(y, G);
    var idx = c.notes.length;
    app.commit('Add Note', function (q) { M.clipById(q, c.id).clip.notes.push({ start: beat, len: grid, pitch: pitch, vel: 100 }); });
    app.sel.notes = [idx];
    hear(pitch, 100); setTimeout(hush, 180);
    // keep dragging to make it longer
    drag = { kind: 'resize', x0: x, y0: y, dBeat: 0, dPitch: 0, dLen: 0, moved: false };
    window.addEventListener('mousemove', onMove);
    window.addEventListener('mouseup', onUp);
    MD.actions.noteActivity(1);
  }

  function onMove(e) {
    if (!drag) return;
    var G = geo(), r = cv.getBoundingClientRect(), x = e.clientX - r.left, y = e.clientY - r.top;
    var p = app.project(), c = clip();
    if (Math.abs(x - drag.x0) > 2 || Math.abs(y - drag.y0) > 2) drag.moved = true;
    if (drag.kind === 'move') {
      var grid = app.grid();
      var raw = (x - drag.x0) / app.view.rollPxPerBeat;
      drag.dBeat = Math.round(raw / grid) * grid;
      var dp = Math.round((drag.y0 - y) / G.rowH);
      if (dp !== drag.dPitch) { drag.dPitch = dp; hear(drag.pitch0 + dp); }
    } else if (drag.kind === 'resize') {
      var g2 = app.grid();
      drag.dLen = Math.round((x - drag.x0) / app.view.rollPxPerBeat / g2) * g2;
    } else if (drag.kind === 'lasso') {
      drag.x1 = x; drag.y1 = y;
      var b1 = beatAt(Math.min(drag.x0, x), G) - c.start, b2 = beatAt(Math.max(drag.x0, x), G) - c.start;
      var p1 = pitchAt(Math.max(drag.y0, y), G), p2 = pitchAt(Math.min(drag.y0, y), G);
      var picked = drag.add.slice();
      c.notes.forEach(function (n, i) {
        if (n.start + n.len >= b1 && n.start <= b2 && n.pitch >= p1 && n.pitch <= p2 && picked.indexOf(i) < 0) picked.push(i);
      });
      app.sel.notes = picked;
    } else if (drag.kind === 'vel') {
      laneVelocity(x, y, G, c);
    } else if (drag.kind === 'cc') {
      laneCC(x, y, G, c);
    }
    draw();
  }
  function onUp() {
    window.removeEventListener('mousemove', onMove);
    window.removeEventListener('mouseup', onUp);
    hush();
    var d = drag; drag = null;
    var c = clip();
    if (!d || !c) { draw(); return; }
    var chosen = app.sel.notes.slice();
    if (d.kind === 'move' && d.moved && (d.dBeat || d.dPitch || d.copy)) {
      app.commit(d.copy ? 'Copy Notes' : 'Move Notes', function (q) {
        var cl = M.clipById(q, c.id).clip, added = [];
        chosen.forEach(function (i) {
          var n = cl.notes[i];
          if (d.copy) { added.push({ start: n.start, len: n.len, pitch: n.pitch, vel: n.vel }); }
          n.start = Math.max(0, n.start + d.dBeat); n.pitch = Math.max(0, Math.min(127, n.pitch + d.dPitch));
        });
        cl.notes = cl.notes.concat(added);
      });
    } else if (d.kind === 'resize' && d.moved && d.dLen) {
      app.commit('Change Note Length', function (q) {
        var cl = M.clipById(q, c.id).clip;
        chosen.forEach(function (i) { cl.notes[i].len = Math.max(1 / 32, cl.notes[i].len + d.dLen); });
      });
    } else if (d.kind === 'vel' && Object.keys(d.vel).length) {
      app.commit('Change Velocity', function (q) {
        var cl = M.clipById(q, c.id).clip;
        Object.keys(d.vel).forEach(function (i) { if (cl.notes[i]) cl.notes[i].vel = d.vel[i]; });
      });
    } else if (d.kind === 'cc') {
      var lane = app.view.lane;
      app.commit('Draw CC' + lane, function (q) { var cl = M.clipById(q, c.id).clip; cl.cc = cl.cc || {}; cl.cc[lane] = d.points; });
    }
    app.changed({ selection: true });
  }

  function laneDown(x, y, G, c) {
    if (app.view.lane === 'vel') { drag = { kind: 'vel', vel: {}, x0: x, y0: y }; laneVelocity(x, y, G, c); }
    else {
      var pts = ((c.cc && c.cc[app.view.lane]) || []).map(function (p) { return p.slice(); });
      drag = { kind: 'cc', points: pts, x0: x, y0: y };
      laneCC(x, y, G, c);
    }
    window.addEventListener('mousemove', onMove);
    window.addEventListener('mouseup', onUp);
  }
  function laneValue(y, G) {
    var inner = G.laneH - 8, base = G.h - 4;
    return Math.max(0, Math.min(127, Math.round((base - y) / inner * 127)));
  }
  // Velocity: drag across the lane and every note under the pointer takes its height.
  function laneVelocity(x, y, G, c) {
    var v = Math.max(1, laneValue(y, G));
    var b0 = beatAt(Math.min(x, drag.lastX === undefined ? x : drag.lastX) - 4, G) - c.start;
    var b1 = beatAt(Math.max(x, drag.lastX === undefined ? x : drag.lastX) + 4, G) - c.start;
    drag.lastX = x;
    var only = app.sel.notes.length ? app.sel.notes : null;
    c.notes.forEach(function (n, i) {
      if (only && only.indexOf(i) < 0) return;
      if (n.start >= b0 && n.start <= b1) drag.vel[i] = v;
    });
  }
  // A controller: points one grid step apart, replaced where the pointer passes.
  function laneCC(x, y, G, c) {
    var grid = Math.min(0.125, app.grid());
    var b = Math.max(0, Math.min(c.length, Math.round((beatAt(x, G) - c.start) / grid) * grid));
    var lastB = drag.lastB === undefined ? b : drag.lastB;
    var v = laneValue(y, G), lastV = drag.lastV === undefined ? v : drag.lastV;
    var lo = Math.min(b, lastB), hi = Math.max(b, lastB);
    drag.points = drag.points.filter(function (p) { return p[0] < lo - 1e-9 || p[0] > hi + 1e-9; });
    for (var s = lo; s <= hi + 1e-9; s += grid) {
      var f = hi === lo ? 1 : (s - lastB) / (b - lastB);
      drag.points.push([Math.round(s * 1000) / 1000, Math.round(lastV + (v - lastV) * Math.max(0, Math.min(1, f)))]);
    }
    drag.points.sort(function (a, b2) { return a[0] - b2[0]; });
    drag.lastB = b; drag.lastV = v;
  }

  function onWheel(e) {
    var G = geo();
    if (e.ctrlKey || e.metaKey) {
      e.preventDefault();
      var r = cv.getBoundingClientRect(), x = e.clientX - r.left, at = beatAt(x, G);
      app.view.rollPxPerBeat = Math.max(8, Math.min(600, app.view.rollPxPerBeat * Math.exp(-e.deltaY * 0.004)));
      app.view.rollScrollX = Math.max(0, at - (x - G.keysW) / app.view.rollPxPerBeat);
    } else if (e.shiftKey || Math.abs(e.deltaX) > Math.abs(e.deltaY)) {
      e.preventDefault();
      app.view.rollScrollX = Math.max(0, app.view.rollScrollX + (e.shiftKey ? e.deltaY : e.deltaX) / app.view.rollPxPerBeat);
    } else {
      e.preventDefault();
      app.view.rollTop = Math.max(20, Math.min(127, app.view.rollTop - e.deltaY / G.rowH / 2));
    }
    draw();
  }
  function onContext(e) {
    e.preventDefault();
    var G = geo(), r = cv.getBoundingClientRect(), y = e.clientY - r.top;
    var c = clip();
    if (!c) return;
    if (y > G.h - G.laneH && app.view.lane !== 'vel') {
      U.menu(null, [
        { label: 'Draw with AutoCC', action: function () { MD.actions.seedCC(); } },
        { label: 'Clear This Lane', action: function () { var lane = app.view.lane; app.commit('Clear CC' + lane, function (q) { var cl = M.clipById(q, c.id).clip; if (cl.cc) delete cl.cc[lane]; }); } }
      ], { x: e.clientX, y: e.clientY });
      return;
    }
    MD.actions.clipMenu(e.clientX, e.clientY);
  }
  function onHover(e) {
    if (drag) return;
    var G = geo(), r = cv.getBoundingClientRect(), x = e.clientX - r.left, y = e.clientY - r.top;
    var h = y > G.rulerH && y < G.h - G.laneH && x > G.keysW ? noteAt(x, y, G) : null;
    cv.style.cursor = app.view.tool === 'draw' ? 'crosshair' : (h ? (h.edge ? 'ew-resize' : 'grab') : 'default');
    var c = clip(), t = app.track(), inst = instrumentOf(t);
    if (h && c && inst && !t.drums) {
      var n = c.notes[h.index];
      var why = n.pitch < inst.low || n.pitch > inst.high ? ' - out of the ' + inst.name + '’s range' :
        (inst.sweet && (n.pitch < inst.sweet[0] || n.pitch > inst.sweet[1]) ? ' - outside where the ' + inst.name + ' sounds best' : '');
      cv.title = U.noteName(n.pitch) + ', velocity ' + n.vel + why;
    } else cv.title = '';
  }

  // Bring the chosen clip into view.
  function reveal() {
    var c = clip();
    if (!c) return;
    var G = geo();
    var vis = (G.w - G.keysW) / app.view.rollPxPerBeat;
    if (c.start < app.view.rollScrollX || c.start + Math.min(c.length, vis) > app.view.rollScrollX + vis) app.view.rollScrollX = Math.max(0, c.start - 0.25);
    if (c.notes.length) {
      var hi = Math.max.apply(null, c.notes.map(function (n) { return n.pitch; }));
      var lo = Math.min.apply(null, c.notes.map(function (n) { return n.pitch; }));
      var rows = (G.h - G.rulerH - G.laneH) / G.rowH;
      if (hi > app.view.rollTop || lo < app.view.rollTop - rows) app.view.rollTop = Math.min(127, Math.round((hi + lo) / 2 + rows / 2));
    }
  }
  function follow() {
    if (!app.view.follow || !MD.audio.isPlaying() || !cv) return;
    var G = geo(), vis = (G.w - G.keysW) / app.view.rollPxPerBeat, pos = MD.audio.position();
    app.view.rollScrollX = Math.max(0, pos - vis / 3);
  }

  var lastClip = null;
  function init() {
    cv = document.getElementById('roll');
    cv.addEventListener('mousedown', onDown);
    cv.addEventListener('wheel', onWheel, { passive: false });
    cv.addEventListener('contextmenu', onContext);
    cv.addEventListener('mousemove', onHover);
    app.on(function () {
      if (app.sel.clipId !== lastClip) { lastClip = app.sel.clipId; reveal(); }
      draw();
    });
    new ResizeObserver(draw).observe(cv);
  }

  MD.roll = { init: init, draw: draw, focus: function () { reveal(); cv.focus(); draw(); }, follow: follow, reveal: reveal, instrumentOf: instrumentOf };
})(globalThis.MD = globalThis.MD || {});
