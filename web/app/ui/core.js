/* The app's state and the pieces every view shares: selection, the caret,
 * the view settings, menus, sheets and the status line.
 *
 * One place owns the project and the selection (Miderator's Controller):
 * every view reads `MD.app` and asks it for changes, and a drag is shown by
 * the view and committed once, on mouse up, as one undo step.
 */
(function (MD) {
  'use strict';
  var M = MD.model;

  // ------------------------------------------------------------ elements --
  function el(tag, attrs, kids) {
    var e = document.createElement(tag);
    if (attrs) Object.keys(attrs).forEach(function (k) {
      var v = attrs[k];
      if (v === undefined || v === null || v === false) return;
      if (k === 'class') e.className = v;
      else if (k === 'text') e.textContent = v;
      else if (k === 'html') e.innerHTML = v;
      else if (k.slice(0, 2) === 'on' && typeof v === 'function') e.addEventListener(k.slice(2), v);
      else if (k === 'style' && typeof v === 'object') Object.assign(e.style, v);
      else e.setAttribute(k, v === true ? '' : v);
    });
    (kids || []).forEach(function (c) {
      if (c === null || c === undefined || c === false) return;
      e.appendChild(typeof c === 'string' ? document.createTextNode(c) : c);
    });
    return e;
  }
  function button(label, onclick, attrs) {
    attrs = attrs || {};
    attrs.type = 'button';
    attrs.onclick = onclick;
    return el('button', attrs, [label]);
  }
  function toggle(label, on, onclick, attrs) {
    attrs = attrs || {};
    attrs['aria-pressed'] = on ? 'true' : 'false';
    return button(label, onclick, attrs);
  }
  function clear(node) { while (node.firstChild) node.removeChild(node.firstChild); return node; }

  // ---------------------------------------------------------------- app ---
  var app = {
    history: null,
    sel: { trackId: null, clipId: null, notes: [], range: null },
    caret: 0,
    view: {
      pxPerBeat: 22, scrollX: 0,
      rollPxPerBeat: 70, rollScrollX: 0, rollTop: 84, rowH: 12,
      grid: 0.25, triplet: false, tool: 'select', lane: 'vel', etab: 'roll',
      follow: true, mixer: false, itab: 'track', trackH: 57
    },
    listeners: [],
    pending: false
  };
  app.project = function () { return app.history.project; };
  app.on = function (f) { app.listeners.push(f); };
  // Redraw once a frame, however many things changed.
  app.changed = function (what) {
    app.pendingWhat = Object.assign(app.pendingWhat || {}, what || { all: true });
    if (app.pending) return;
    app.pending = true;
    requestAnimationFrame(function () {
      app.pending = false;
      var w = app.pendingWhat; app.pendingWhat = null;
      app.listeners.forEach(function (f) { f(w); });
    });
  };
  app.commit = function (label, fn) {
    var r = app.history.commit(label, fn);
    app.validate();
    app.changed({ project: true });
    return r;
  };
  app.validate = function () {
    var p = app.project();
    if (app.sel.trackId && !M.track(p, app.sel.trackId)) app.sel.trackId = p.tracks[0] ? p.tracks[0].id : null;
    if (!app.sel.trackId && p.tracks[0]) app.sel.trackId = p.tracks[0].id;
    if (app.sel.clipId && !M.clipById(p, app.sel.clipId)) { app.sel.clipId = null; app.sel.notes = []; }
  };
  app.track = function () { return app.sel.trackId ? M.track(app.project(), app.sel.trackId) : null; };
  app.clip = function () { var f = app.sel.clipId ? M.clipById(app.project(), app.sel.clipId) : null; return f ? f.clip : null; };
  app.selectTrack = function (id, keepRange) {
    app.sel.trackId = id;
    if (!keepRange && app.sel.range && app.sel.range.trackIds.indexOf(id) < 0) app.sel.range = null;
    var t = app.track();
    if (t && app.sel.clipId && !t.clips.some(function (c) { return c.id === app.sel.clipId; })) {
      app.sel.clipId = null; app.sel.notes = [];
    }
    // A track's music opens in the editor with it: the clip under the caret,
    // or its first one.
    if (t && !app.sel.clipId && !app.sel.range && t.clips.length) {
      var at = MD.model.clipAt(t, app.caret) || t.clips[0];
      app.sel.clipId = at.id;
    }
    app.changed({ selection: true });
  };
  app.selectClip = function (trackId, clipId) {
    app.sel.trackId = trackId; app.sel.clipId = clipId; app.sel.notes = []; app.sel.range = null;
    app.changed({ selection: true });
  };
  // Bars chosen across tracks: where generated music goes (Miderator 0019).
  app.chooseRange = function (trackIds, start, end) {
    app.sel.range = trackIds.length ? { trackIds: trackIds, start: start, end: end } : null;
    app.sel.clipId = null; app.sel.notes = [];
    app.changed({ selection: true });
  };
  app.setCaret = function (beat) { app.caret = Math.max(0, beat); app.changed({ caret: true }); };
  app.grid = function () { var g = app.view.grid; return app.view.triplet ? g * 2 / 3 : g; };

  // ------------------------------------------------------------- status ---
  // Messages appear at the top and stay until dismissed or replaced; one can
  // carry an Undo.
  var statusUndo = null;
  function status(text, opts) {
    opts = opts || {};
    var box = document.getElementById('status');
    document.getElementById('status-text').textContent = text;
    box.hidden = !text;
    box.classList.toggle('warning', !!opts.warning);
    var u = document.getElementById('status-undo');
    statusUndo = opts.undo || null;
    u.hidden = !statusUndo;
  }
  function initStatus() {
    document.getElementById('status-dismiss').onclick = function () { status(''); };
    document.getElementById('status-undo').onclick = function () {
      var f = statusUndo; status('');
      if (f) f();
    };
  }

  // -------------------------------------------------------------- menus ---
  var openMenu = null;
  function closeMenu() {
    if (!openMenu) return;
    var layer = document.getElementById('menu-layer');
    clear(layer); layer.hidden = true;
    if (openMenu.anchor) { openMenu.anchor.classList.remove('open'); openMenu.anchor.focus(); }
    openMenu = null;
  }
  // items: { label, keys, action, checked, disabled, heading, separator }
  function menu(anchor, items, pos) {
    closeMenu();
    var layer = document.getElementById('menu-layer');
    layer.hidden = false;
    var m = el('div', { class: 'menu', role: 'menu' });
    items.forEach(function (it) {
      if (it.separator) { m.appendChild(el('hr')); return; }
      if (it.heading) { m.appendChild(el('div', { class: 'heading', text: it.heading })); return; }
      var b = el('button', { type: 'button', role: it.checked !== undefined ? 'menuitemcheckbox' : 'menuitem',
        class: it.checked ? 'checked' : null, disabled: it.disabled || null, 'aria-checked': it.checked !== undefined ? String(!!it.checked) : null,
        onclick: function () { closeMenu(); if (it.action) it.action(); } },
        [el('span', { text: it.label }), it.keys ? el('span', { class: 'keys', text: it.keys }) : null]);
      m.appendChild(b);
    });
    layer.appendChild(m);
    var r = anchor ? anchor.getBoundingClientRect() : { left: pos.x, bottom: pos.y, top: pos.y };
    var x = r.left, y = r.bottom + 2;
    m.style.left = '0px'; m.style.top = '0px';
    var mw = m.offsetWidth, mh = m.offsetHeight;
    if (x + mw > innerWidth - 8) x = Math.max(8, innerWidth - mw - 8);
    if (y + mh > innerHeight - 8) y = Math.max(8, (anchor ? r.top : pos.y) - mh - 2);
    m.style.left = x + 'px'; m.style.top = y + 'px';
    if (anchor) anchor.classList.add('open');
    openMenu = { el: m, anchor: anchor };
    layer.onmousedown = function (e) { if (e.target === layer) closeMenu(); };
    layer.oncontextmenu = function (e) { e.preventDefault(); closeMenu(); };
    var first = m.querySelector('button:not([disabled])');
    if (first) first.focus();
    m.onkeydown = function (e) {
      var bs = Array.prototype.slice.call(m.querySelectorAll('button:not([disabled])'));
      var i = bs.indexOf(document.activeElement);
      if (e.key === 'ArrowDown') { e.preventDefault(); (bs[(i + 1) % bs.length] || bs[0]).focus(); }
      else if (e.key === 'ArrowUp') { e.preventDefault(); (bs[(i - 1 + bs.length) % bs.length] || bs[0]).focus(); }
      else if (e.key === 'Escape') { e.preventDefault(); e.stopPropagation(); closeMenu(); }
    };
  }

  // ------------------------------------------------------------- sheets ---
  var openSheet = null;
  function sheet(title, build, opts) {
    closeSheet();
    var layer = document.getElementById('sheet-layer');
    layer.hidden = false;
    var box = el('div', { class: 'sheet', role: 'dialog', 'aria-modal': 'true', 'aria-label': title });
    if (opts && opts.wide) box.style.width = 'min(72rem, 96vw)';
    box.appendChild(el('h2', { text: title }));
    var body = el('div');
    box.appendChild(body);
    layer.appendChild(box);
    openSheet = { el: box, onClose: opts && opts.onClose };
    build(body, closeSheet);
    layer.onmousedown = function (e) { if (e.target === layer) closeSheet(); };
    var f = box.querySelector('input, button, select');
    if (f) f.focus();
    return closeSheet;
  }
  function closeSheet() {
    if (!openSheet) return;
    var layer = document.getElementById('sheet-layer');
    clear(layer); layer.hidden = true;
    var cb = openSheet.onClose; openSheet = null;
    if (cb) cb();
  }

  // ----------------------------------------------------------- tooltips ---
  var tip = null;
  function tooltip(text, x, y) {
    if (!text) { if (tip) { tip.remove(); tip = null; } return; }
    if (!tip) { tip = el('div', { class: 'tooltip', role: 'tooltip' }); document.body.appendChild(tip); }
    tip.textContent = text;
    var w = tip.offsetWidth, h = tip.offsetHeight;
    tip.style.left = Math.min(innerWidth - w - 8, x + 12) + 'px';
    tip.style.top = Math.min(innerHeight - h - 8, y + 16) + 'px';
  }

  // ------------------------------------------------------------- canvas ---
  // A canvas the size it is shown, at the screen's own resolution.
  function fit(canvas, w, h) {
    var dpr = window.devicePixelRatio || 1;
    w = Math.max(1, Math.floor(w)); h = Math.max(1, Math.floor(h));
    if (canvas.width !== w * dpr || canvas.height !== h * dpr) {
      canvas.width = w * dpr; canvas.height = h * dpr;
    }
    canvas.style.width = w + 'px'; canvas.style.height = h + 'px';
    var g = canvas.getContext('2d');
    g.setTransform(dpr, 0, 0, dpr, 0, 0);
    return g;
  }
  function css(name) { return getComputedStyle(document.documentElement).getPropertyValue(name).trim(); }
  function rem() { return parseFloat(getComputedStyle(document.documentElement).fontSize) || 13; }

  function noteName(pitch, key) {
    var names = MD.engines.isReady() ? MD.engines.noteNames(key || app.project().key) : ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
    return names[pitch % 12] + (Math.floor(pitch / 12) - 1);
  }

  MD.ui = { el: el, button: button, toggle: toggle, clear: clear, status: status, initStatus: initStatus,
            menu: menu, closeMenu: closeMenu, isMenuOpen: function () { return !!openMenu; },
            sheet: sheet, closeSheet: closeSheet, isSheetOpen: function () { return !!openSheet; },
            tooltip: tooltip, fit: fit, css: css, rem: rem, noteName: noteName };
  MD.app = app;
})(globalThis.MD = globalThis.MD || {});
