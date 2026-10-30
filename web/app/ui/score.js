/* The score: the same notes, engraved.
 *
 * Starting Blocks Notation's engraver (sb_notate.lua) lays the part out and
 * its ink (sb_draw.lua) draws it with Bravura's own outlines (sb_glyphs.lua),
 * all unchanged; this file is only the pen - four calls, line, poly, circle
 * and text - on a canvas. The score is worked out from the notes every time
 * (Miderator 0002): nothing about notation is stored.
 */
(function (MD) {
  'use strict';
  var app = MD.app, M = MD.model, U = MD.ui, L = globalThis.MiddawLua;
  var box, cv, full = false, light = false, cache = null;

  function rgba(c) {
    var n = typeof c === 'number' ? c : (c && c.n !== undefined ? c.n : 0xDDE1E7FF);
    var r = Math.floor(n / 16777216) % 256, g = Math.floor(n / 65536) % 256, b = Math.floor(n / 256) % 256, a = n % 256;
    return 'rgba(' + r + ',' + g + ',' + b + ',' + (a / 255).toFixed(3) + ')';
  }
  function pen(g) {
    var P = new L.LuaTable();
    P.set('line', function (x1, y1, x2, y2, col, th) {
      g.strokeStyle = rgba(col); g.lineWidth = th === undefined ? 1 : +th; g.lineCap = 'butt';
      g.beginPath(); g.moveTo(+x1, +y1); g.lineTo(+x2, +y2); g.stroke();
      return L.NONE;
    });
    P.set('poly', function (pts, col) {
      var a = pts.arr;
      if (a.length < 6) return L.NONE;
      g.fillStyle = rgba(col);
      g.beginPath(); g.moveTo(+a[0], +a[1]);
      for (var i = 2; i < a.length; i += 2) g.lineTo(+a[i], +a[i + 1]);
      g.closePath(); g.fill();
      return L.NONE;
    });
    P.set('circle', function (x, y, r, col, filled) {
      g.beginPath(); g.arc(+x, +y, Math.max(0.5, +r), 0, Math.PI * 2);
      if (L.T(filled)) { g.fillStyle = rgba(col); g.fill(); }
      else { g.strokeStyle = rgba(col); g.lineWidth = Math.max(1, +r * 0.4); g.stroke(); }
      return L.NONE;
    });
    P.set('text', function (x, y, col, str, size, center) {
      g.fillStyle = rgba(col);
      g.font = '600 ' + Math.max(8, +size) + 'px -apple-system, system-ui, sans-serif';
      g.textBaseline = 'middle'; g.textAlign = L.T(center) ? 'center' : 'left';
      g.fillText(L.fromBytes(L.tostring(str)), +x, +y);
      g.textAlign = 'left';
      return L.NONE;
    });
    return P;
  }

  // One track as an engraved part.
  function engrave(t, widthPx, sp) {
    var p = app.project(), E = MD.engines, N = E.notation();
    var end = Math.max(M.beatsPerBar(p), Math.ceil(M.endOfMusic(p) / M.beatsPerBar(p)) * M.beatsPerBar(p));
    var notes = written(M.trackNotes(t));
    var block = L.toLua({ notes: notes, beats: end, name: t.name });
    var st = L.first(L.call(L.index(N.E, 'newState'))());
    st.set('root', p.key.root); st.set('scale', p.key.scale); st.set('barBeats', M.beatsPerBar(p));
    var ctx = L.first(L.call(L.index(N.N, 'context'))(N.E, st));
    var opts = L.toLua({ barBeats: M.beatsPerBar(p), tsNum: p.meter[0], tsDen: p.meter[1], width: widthPx / sp,
                         drums: !!t.drums, grid: t.drums ? 0.25 : undefined });
    opts.set('ctx', ctx);
    return L.first(L.call(L.index(N.N, 'layout'))(block, opts));
  }

  // Played and humanised onsets, put back on the grid they were meant on: a
  // sixteenth unless a triplet fits clearly better. The page writes each note
  // up to the next onset (Starting Blocks Notation's rule), so a few ms of
  // feel would otherwise print as thirty-second notes.
  function written(list) {
    var seen = {}, out = [];
    list.forEach(function (n) {
      var q4 = Math.round(n.start * 4) / 4, q3 = Math.round(n.start * 3) / 3;
      var at = Math.abs(n.start - q4) <= Math.abs(n.start - q3) + 0.04 ? q4 : q3;
      var k = at.toFixed(4) + ':' + n.pitch;
      if (seen[k]) return;
      seen[k] = true;
      out.push({ start: at, len: Math.max(0.25, n.len), pitch: n.pitch, vel: n.vel });
    });
    return out;
  }

  function draw() {
    if (!box || box.hidden) return;
    var p = app.project(), E = MD.engines;
    if (!E.isReady()) return;
    var r = U.rem(), sp = Math.round(0.68 * r);
    var width = Math.max(200, box.clientWidth - 2.6 * r);
    var tracks = full ? p.tracks : (app.track() ? [app.track()] : []);
    var key = JSON.stringify([width, sp, full, light, p.key, p.meter, tracks.map(function (t) { return [t.id, t.name, t.drums, t.clips]; })]);
    if (!cache || cache.key !== key) {
      var docs = tracks.map(function (t) {
        try { return { t: t, doc: engrave(t, width, sp) }; }
        catch (e) { console.error(e); return { t: t, err: String(e.message || e) }; }
      });
      cache = { key: key, docs: docs };
    }
    var N = E.notation();
    var heights = cache.docs.map(function (d) { return d.doc ? +L.first(L.call(L.index(N.D, 'height'))(d.doc, sp)) : 3 * r; });
    var titleH = Math.round(1.8 * r);
    var total = heights.reduce(function (a, b) { return a + b + titleH; }, Math.round(r));
    var g = U.fit(cv, box.clientWidth, Math.max(box.clientHeight, total));
    var colours = light ? { ink: 0x14171CFF, staff: 0x3A404AFF, ground: 0xF2F4F7FF, accent: 0xB0A800FF, paper: '#F2F4F7', title: '#14171C' }
                        : { ink: 0xDDE1E7FF, staff: 0x8A919CFF, ground: 0x111419FF, accent: 0xFFF200FF, paper: '#111419', title: '#DDE1E7' };
    g.fillStyle = colours.paper; g.fillRect(0, 0, box.clientWidth, Math.max(box.clientHeight, total));
    var col = L.toLua({ ink: colours.ink, staff: colours.staff, ground: colours.ground, accent: colours.accent });
    var playing = MD.audio.isPlaying(), at = playing ? MD.audio.position() * 960 : -1;
    var opts = new L.LuaTable();
    if (playing) opts.set('highlight', function (el) {
      var abs = L.index(el, 'abs'), ticks = L.index(el, 'ticks');
      return abs !== undefined && at >= +abs && at < +abs + +ticks;
    });
    var y = Math.round(0.5 * r), P = pen(g);
    if (!cache.docs.length) {
      g.fillStyle = U.css('--text-dim'); g.font = r + 'px -apple-system, system-ui, sans-serif';
      g.fillText('Choose a track to see its part.', r * 2, r * 3);
    }
    cache.docs.forEach(function (d, i) {
      g.fillStyle = colours.title; g.font = '600 ' + r + 'px -apple-system, system-ui, sans-serif'; g.textBaseline = 'top';
      g.fillText(d.t.name, 1.4 * r, y + 0.3 * r);
      y += titleH;
      if (d.doc) {
        try { L.call(L.index(N.D, 'page'))(P, d.doc, 1.4 * r, y, sp, col, opts); }
        catch (e) { console.error(e); }
      } else {
        g.fillStyle = U.css('--warn-text'); g.fillText('This part could not be engraved: ' + d.err, 1.4 * r, y);
      }
      y += heights[i];
    });
  }

  function init() {
    box = document.getElementById('score');
    cv = document.getElementById('score-canvas');
    app.on(function () { draw(); });
    new ResizeObserver(function () { cache = null; draw(); }).observe(box);
  }

  MD.score = {
    init: init, draw: draw,
    full: function () { return full; }, setFull: function (v) { full = v; cache = null; draw(); },
    light: function () { return light; }, setLight: function (v) { light = v; cache = null; draw(); }
  };
})(globalThis.MD = globalThis.MD || {});
