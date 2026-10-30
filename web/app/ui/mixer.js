/* The mixer: a channel strip per track, the reverb return and the master,
 * in place of the editor (M). Levels move as you drag and are kept, as one
 * undo step, when you let go.
 */
(function (MD) {
  'use strict';
  var app = MD.app, M = MD.model, U = MD.ui;
  var box, meters = {}, levels = {};

  function strip(t) {
    var sel = t.id === app.sel.trackId;
    var meter = U.el('canvas', { 'aria-hidden': 'true' });
    meters[t.id] = meter;
    var val = U.el('span', { class: 'val', text: MD.mixText.db(t.volume) });
    var fader = U.el('input', { type: 'range', class: 'vertical', min: 0, max: 1, step: 0.005, value: t.volume, 'aria-label': t.name + ' level',
      'aria-valuetext': MD.mixText.db(t.volume) });
    fader.oninput = function () { val.textContent = MD.mixText.db(+fader.value); MD.audio.setMix(t.id, { volume: +fader.value }); };
    fader.onchange = function () { app.commit('Change Level', function (q) { M.track(q, t.id).volume = +fader.value; }); };
    fader.ondblclick = function () { app.commit('Reset Level', function (q) { M.track(q, t.id).volume = 0.8; }); };
    var pan = U.el('input', { type: 'range', min: -1, max: 1, step: 0.01, value: t.pan, 'aria-label': t.name + ' pan', title: MD.mixText.pan(t.pan), style: { width: '100%' } });
    pan.oninput = function () { pan.title = MD.mixText.pan(+pan.value); MD.audio.setMix(t.id, { pan: +pan.value }); };
    pan.onchange = function () { app.commit('Change Pan', function (q) { M.track(q, t.id).pan = +pan.value; }); };
    var send = U.el('input', { type: 'range', min: 0, max: 1, step: 0.01, value: t.send || 0, 'aria-label': t.name + ' reverb send', title: 'Reverb', style: { width: '100%' } });
    send.oninput = function () { MD.audio.setMix(t.id, { send: +send.value }); };
    send.onchange = function () { app.commit('Change Reverb Send', function (q) { M.track(q, t.id).send = +send.value; }); };
    return U.el('div', { class: 'strip' + (sel ? ' selected' : ''), onmousedown: function (e) { if (e.target.tagName !== 'INPUT' && e.target.tagName !== 'BUTTON') app.selectTrack(t.id); } }, [
      U.el('div', { class: 'name', text: t.name, title: t.name }),
      U.el('span', { class: 'val', text: 'Reverb' }), send,
      pan,
      U.el('div', { class: 'faders' }, [fader, meter]),
      val,
      U.el('div', { class: 'row' }, [
        U.toggle('M', t.mute, function () { app.commit('Mute', function (q) { var x = M.track(q, t.id); x.mute = !x.mute; }); }, { 'aria-label': 'Mute ' + t.name }),
        U.toggle('S', t.solo, function () { app.commit('Solo', function (q) { var x = M.track(q, t.id); x.solo = !x.solo; }); }, { 'aria-label': 'Solo ' + t.name })
      ])
    ]);
  }

  function render() {
    if (!box || box.hidden) return;
    U.clear(box); meters = {};
    var p = app.project();
    p.tracks.forEach(function (t) { box.appendChild(strip(t)); });
    var ret = p.returns && p.returns[0];
    if (ret) {
      box.appendChild(U.el('div', { class: 'strip' }, [U.el('div', { class: 'name', text: 'Reverb' }),
        U.el('span', { class: 'val', text: ret.audioFx.map(function (d) { return MD.devices.DEVICES[d.device].name; }).join(', ') }),
        U.button('Edit', function () { MD.actions.inspectorTab('track'); }, { title: 'Its controls are under the track in the inspector' })]));
    }
  }
  function drawMeters() {
    if (!box || box.hidden) return;
    Object.keys(meters).forEach(function (id) {
      var cv = meters[id];
      var h = cv.clientHeight, w = cv.clientWidth;
      if (!h || !w) return;
      var g = U.fit(cv, w, h), lv = levels[id] || { l: 0, r: 0 };
      g.fillStyle = U.css('--sunken'); g.fillRect(0, 0, w, h);
      [lv.l, lv.r].forEach(function (v, i) {
        var db = v > 0 ? 20 * Math.log10(v) : -60, f = Math.max(0, Math.min(1, (db + 60) / 66));
        g.fillStyle = db > -0.5 ? U.css('--warn') : U.css('--control');
        g.fillRect(i * w / 2, h * (1 - f), w / 2 - 1, h * f);
      });
    });
  }

  function init() {
    box = document.getElementById('mixer');
    MD.audio.on('meter', function (id, m) {
      var lv = levels[id] || (levels[id] = { l: 0, r: 0 });
      lv.l = Math.max(m.l, lv.l * 0.82); lv.r = Math.max(m.r, lv.r * 0.82);
    });
    app.on(function (w) { if (w.project || w.selection || w.all) render(); });
    (function loop() { drawMeters(); requestAnimationFrame(loop); })();
  }

  MD.mixer = { init: init, render: render };
})(globalThis.MD = globalThis.MD || {});
