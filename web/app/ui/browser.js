/* The browser, down the left: what to add, where ideas come from, and what
 * the orchestration books say.
 *
 *   Sounds         ensembles to start a song from (Noterator's templates),
 *                  every instrument, every device
 *   Ideas          Midi Catalogue's ideas for the chosen track's instrument,
 *                  in the song's key; and the ideas the Battle Pass gave you
 *   Orchestration  the Orchestration Helper, searchable
 */
(function (MD) {
  'use strict';
  var app = MD.app, M = MD.model, U = MD.ui, E = MD.engines, D = MD.devices;
  var body, tab = 'sounds', query = '', entryId = null, catSession = null, catResults = [], catChosen = -1, catOpen = { Catalogue: true };

  var ENSEMBLES = [
    { name: 'Piano', group: 'Solo and small', ids: ['pno'] },
    { name: 'String Quartet', group: 'Solo and small', ids: ['vln1', 'vln2', 'vla', 'vc'] },
    { name: 'Wind Quintet', group: 'Solo and small', ids: ['fl', 'ob', 'cl', 'hn', 'bsn'] },
    { name: 'Brass Quintet', group: 'Solo and small', ids: ['tpt', 'tpt', 'hn', 'tbn', 'tuba'] },
    { name: 'Choir', group: 'Solo and small', ids: ['sop', 'alto', 'ten', 'bass'] },
    { name: 'Band', group: 'Solo and small', ids: ['pno', 'gtr', 'ebass', 'kit'] },
    { name: 'Jazz Combo', group: 'Solo and small', ids: ['tpt', 'tsax', 'pno', 'ubass', 'kit'] },
    { name: 'Beat Maker', group: 'Solo and small', ids: ['synth', 'pno', 'ebass', 'kit'] },
    { name: 'Full Strings', group: 'Orchestral sections', ids: ['vln1', 'vln2', 'vla', 'vc', 'cb'] },
    { name: 'Full Woodwinds', group: 'Orchestral sections', ids: ['picc', 'fl', 'fl', 'ob', 'ob', 'eh', 'cl', 'cl', 'bcl', 'bsn', 'bsn', 'cbsn'] },
    { name: 'Full Brass', group: 'Orchestral sections', ids: ['hn', 'hn', 'hn', 'hn', 'tpt', 'tpt', 'tpt', 'tbn', 'tbn', 'btbn', 'tuba'] },
    { name: 'Orchestral Percussion', group: 'Orchestral sections', ids: ['timp', 'glock', 'xyl', 'mar', 'vib'] },
    { name: 'Chamber Orchestra', group: 'Orchestras and bands', ids: ['fl', 'ob', 'cl', 'bsn', 'hn', 'tpt', 'timp', 'vln1', 'vln2', 'vla', 'vc', 'cb'] },
    { name: 'Full Orchestra', group: 'Orchestras and bands', ids: ['picc', 'fl', 'fl', 'ob', 'ob', 'cl', 'cl', 'bsn', 'bsn', 'hn', 'hn', 'hn', 'hn',
      'tpt', 'tpt', 'tpt', 'tbn', 'tbn', 'btbn', 'tuba', 'timp', 'glock', 'harp', 'vln1', 'vln2', 'vla', 'vc', 'cb'] },
    { name: 'Big Band', group: 'Orchestras and bands', ids: ['asax', 'asax', 'tsax', 'tsax', 'bsax', 'tpt', 'tpt', 'tpt', 'tpt', 'tbn', 'tbn', 'tbn', 'btbn', 'gtr', 'pno', 'ubass', 'kit'] }
  ];

  function instruments() { return E.instruments().filter(function (i) { return i.low !== undefined; }); }

  function soundsTab() {
    var kids = [];
    kids.push(U.el('h4', { text: 'Ensembles' }));
    var ens = U.el('div', { class: 'list' });
    ENSEMBLES.forEach(function (e) {
      ens.appendChild(U.button(e.name, function () { MD.actions.addEnsemble(e); }, { title: 'Add ' + e.ids.length + (e.ids.length === 1 ? ' track' : ' tracks') }));
    });
    kids.push(ens);
    kids.push(U.el('h4', { text: 'Instruments' }));
    var fams = {};
    instruments().forEach(function (i) { (fams[i.family] = fams[i.family] || []).push(i); });
    Object.keys(fams).forEach(function (f) {
      var list = U.el('div', { class: 'list', role: 'group', 'aria-label': f });
      list.appendChild(U.el('h4', { text: f }));
      fams[f].forEach(function (i) {
        list.appendChild(U.button(i.name, function () { MD.actions.addInstrument(i.id); }, { title: 'Add a track for the ' + i.name }));
      });
      kids.push(list);
    });
    kids.push(U.el('h4', { text: 'Devices' }));
    ['instrument', 'midi', 'audio'].forEach(function (type) {
      var list = U.el('div', { class: 'list' });
      list.appendChild(U.el('h4', { text: type === 'instrument' ? 'Instruments' : (type === 'midi' ? 'MIDI Effects' : 'Audio Effects') }));
      Object.keys(D.DEVICES).forEach(function (k) {
        var d = D.DEVICES[k];
        if (d.type !== type) return;
        list.appendChild(U.button(d.name, function () {
          var t = app.track();
          if (!t) { U.status('Choose a track first.'); return; }
          MD.actions.addDevice(t.id, k);
        }, { title: type === 'instrument' ? 'Play the chosen track with ' + d.name : 'Add to the chosen track' }));
      });
      kids.push(list);
    });
    return kids;
  }

  // ------------------------------------------------------------ ideas ----
  function catalogue() {
    if (!catSession) { catSession = new E.Session('midi-catalogue'); catSession.useKey(app.project().key); }
    return catSession;
  }
  function catContext() {
    var p = app.project(), t = app.track(), bpb = M.beatsPerBar(p);
    return { root: p.key.root, scale: p.key.scale, num: p.meter[0], den: p.meter[1], barBeats: bpb, bpm: p.tempo,
             inst: t ? t.instrument : 'pno', catalogueId: t && !t.drums ? t.instrument : (t && t.drums ? 'timp' : 'pno'),
             bars: 4, selection: { notes: [], beats: 0, drums: false } };
  }
  function ideasTab() {
    var kids = [];
    var t = app.track();
    if (!t) return [U.el('p', { class: 'note-line', text: 'Choose a track to see ideas for its instrument.' })];
    var ses = catalogue();
    ses.useKey(app.project().key);
    var settings = ses.settings(catContext());
    kids.push(U.el('p', { class: 'note-line', text: 'For the ' + (MD.roll.instrumentOf(t) || { name: t.name }).name + ', in ' + M.keyInfo(app.project().key).label }));
    var sec = U.el('div', {});
    settings.forEach(function (s) {
      if (s.id === 'root' || s.id === 'scale' || s.id === 'inst') return;
      var sel = U.el('select', { 'aria-label': s.label });
      s.names.forEach(function (nm, i) { sel.appendChild(U.el('option', { value: i, text: nm, selected: i === s.index - 1 || null })); });
      sel.onchange = function () { ses.set(s.id, Number(sel.value) + 1, catContext()); catResults = []; render(); };
      sec.appendChild(U.el('div', { class: 'rowline' }, [U.el('span', { class: 'lbl', text: s.label }), sel]));
    });
    kids.push(sec);
    kids.push(U.el('div', { class: 'rowline' }, [U.button('Browse', function () { browseCatalogue(); }, { class: 'primary' })]));
    if (catResults.message) kids.push(U.el('p', { class: 'note-line', text: catResults.message }));
    if (catResults.length) {
      var list = U.el('div', { class: 'results', role: 'listbox', 'aria-label': 'Ideas' });
      catResults.slice(0, 60).forEach(function (r, i) {
        list.appendChild(U.el('button', { type: 'button', class: 'result', role: 'option', 'aria-pressed': String(i === catChosen), 'aria-selected': String(i === catChosen),
          title: 'Click to hear, double-click to put it in at the caret',
          onclick: function () { catChosen = i; MD.audio.audition(r.parts, { tempo: app.project().tempo }); render(); },
          ondblclick: function () { insertIdea(r); } },
          [U.el('span', { class: 't', text: r.title }), r.detail ? U.el('span', { class: 'd', text: r.detail }) : null]));
      });
      kids.push(list);
      kids.push(U.el('div', { class: 'rowline' }, [U.button('Insert at the Caret', function () { insertIdea(catResults[catChosen]); }, { disabled: catChosen < 0 || null })]));
    }
    var won = MD.pass.ideas();
    if (won.length) {
      kids.push(U.el('h4', { text: 'Ideas from the Battle Pass' }));
      var wl = U.el('div', { class: 'list' });
      won.forEach(function (idea) {
        wl.appendChild(U.button(idea.title, function () { MD.pass.useIdea(idea); }, { title: idea.detail || '' }));
      });
      kids.push(wl);
    }
    return kids;
  }
  function browseCatalogue() {
    try {
      var r = catalogue().generate(catContext(), 1, 200);
      catResults = (r.results || []).filter(function (x) { return x.parts && x.parts.length; });
      catResults.message = r.message ? String(r.message) : '';
      catChosen = -1;
    } catch (e) { console.error(e); U.status('The catalogue stopped: ' + e.message, { warning: true }); }
    render();
  }
  function insertIdea(r) {
    if (!r) return;
    var t = app.track(), p = app.project(), bpb = M.beatsPerBar(p);
    if (!t) return;
    MD.audio.stopAudition();
    var notes = [];
    r.parts.forEach(function (pt) { notes = notes.concat(pt.notes); });
    var beats = Math.ceil((r.beats || notes.reduce(function (m, n) { return Math.max(m, n.start + n.len); }, 0)) / bpb - 1e-6) * bpb;
    var at = Math.floor(app.caret / bpb + 1e-9) * bpb, id = null;
    app.commit('Insert Idea', function (q) { id = M.placeNotes(q, t.id, at, beats, MD.generate.fitToInstrument(notes, t, 'melody'), { name: r.title, source: { generator: 'Midi Catalogue', title: r.title } }).id; });
    app.selectClip(t.id, id);
    app.setCaret(at + beats);
    MD.pass.event('idea', 1);
  }

  // ---------------------------------------------------- orchestration ----
  function fold(s) { return String(s || '').toLowerCase().replace(/[^a-z0-9 ]+/g, ' ').trim(); }
  function asList(x) { return !x ? [] : Array.isArray(x) ? x : Object.keys(x).map(function (k) { return x[k]; }); }
  function search(q) {
    var o = E.orchestration(), f = fold(q);
    if (!f) return [];
    var scored = [];
    o.entries.forEach(function (e) {
      var names = [e.name].concat(asList(e.aliases)).map(fold);
      var s = 0;
      names.forEach(function (n) { if (n === f) s = Math.max(s, 100); else if (n.indexOf(f) === 0) s = Math.max(s, 60); else if (n.indexOf(f) >= 0) s = Math.max(s, 40); });
      if (!s && fold(e.summary).indexOf(f) >= 0) s = 10;
      if (s) scored.push({ e: e, s: s });
    });
    scored.sort(function (a, b) { return b.s - a.s || a.e.name.localeCompare(b.e.name); });
    return scored.map(function (x) { return x.e; });
  }
  function learnTab() {
    var o = E.orchestration(), kids = [];
    var field = U.el('input', { type: 'search', placeholder: 'trombone, Herrmann, mysterious', value: query, 'aria-label': 'Search the orchestration books' });
    field.oninput = function () { query = field.value; entryId = null; render(); var f = body.querySelector('input[type=search]'); if (f) { f.focus(); f.setSelectionRange(f.value.length, f.value.length); } };
    kids.push(U.el('div', { class: 'rowline' }, [field]));
    if (entryId) {
      var e = o.entries.find(function (x) { return x.id === entryId; });
      if (e) { kids.push(U.button('Back', function () { entryId = null; render(); })); kids = kids.concat(entryView(e, o)); return kids; }
    }
    var list = query ? search(query) : null;
    if (list) {
      var l = U.el('div', { class: 'list' });
      if (!list.length) l.appendChild(U.el('p', { class: 'note-line', text: 'Nothing by that name. Try an instrument, a section, a composer or a mood.' }));
      list.slice(0, 40).forEach(function (e) { l.appendChild(U.button(e.name, function () { entryId = e.id; render(); }, {}, [])); });
      kids.push(l);
      return kids;
    }
    var fams = {};
    o.entries.forEach(function (e) { (fams[e.family || 'Other'] = fams[e.family || 'Other'] || []).push(e); });
    Object.keys(fams).forEach(function (f) {
      var l = U.el('div', { class: 'list', role: 'group', 'aria-label': f });
      l.appendChild(U.el('h4', { text: f + ' (' + fams[f].length + ')' }));
      fams[f].forEach(function (e) { l.appendChild(U.button(e.name, function () { entryId = e.id; render(); })); });
      kids.push(l);
    });
    return kids;
  }
  function entryView(e, o) {
    var kids = [U.el('h4', { text: e.name, style: { fontSize: '1.15rem', color: 'var(--text)' } })];
    if (e.summary) kids.push(U.el('div', { class: 'prose' }, [U.el('p', { text: e.summary })]));
    var facts = asList(e.facts);
    if (facts.length) {
      var dl = U.el('dl', { class: 'facts' });
      facts.forEach(function (f) { f = asList(f); dl.appendChild(U.el('dt', { text: f[0] })); dl.appendChild(U.el('dd', { text: f[1] })); });
      kids.push(dl);
    }
    asList(e.sec).forEach(function (s) {
      s = asList(s);
      var items = asList(s[1]);
      var box = U.el('div', { class: 'prose' }, [U.el('h4', { text: s[0] })]);
      items.forEach(function (it) {
        it = asList(it);
        var src = it[2] ? String(it[2]) : '';
        box.appendChild(U.el('p', {}, [U.el('strong', { text: it[0] + ': ' }), String(it[1] || ''), src ? U.el('span', { class: 'cite', text: '  ' + src }) : null]));
      });
      kids.push(box);
    });
    var see = asList(e.see);
    if (see.length) {
      kids.push(U.el('h4', { text: 'See also' }));
      kids.push(U.el('div', { class: 'choices' }, see.map(function (id) {
        var t = o.entries.find(function (x) { return x.id === id; });
        return t ? U.button(t.name, function () { entryId = t.id; render(); }) : null;
      }).filter(Boolean)));
    }
    return kids;
  }

  function render() {
    if (!body) return;
    var scroll = body.scrollTop;
    U.clear(body);
    if (!E.isReady()) { body.appendChild(U.el('p', { class: 'note-line', text: 'Loading…' })); return; }
    var kids = tab === 'sounds' ? soundsTab() : tab === 'ideas' ? ideasTab() : learnTab();
    kids.forEach(function (k) { if (k) body.appendChild(k); });
    body.scrollTop = scroll;
    document.querySelectorAll('#browser [role=tab]').forEach(function (b) { b.setAttribute('aria-selected', String(b.dataset.tab === tab)); });
  }
  function setTab(t) { tab = t; render(); }

  var lastTrack = null;
  function init() {
    body = document.getElementById('browser-body');
    document.querySelectorAll('#browser [role=tab]').forEach(function (b) { b.onclick = function () { setTab(b.dataset.tab); }; });
    app.on(function (w) {
      if (tab === 'ideas' && app.sel.trackId !== lastTrack) { lastTrack = app.sel.trackId; catResults = []; render(); }
      else if (w.all) render();
    });
  }

  MD.browser = { init: init, render: render, setTab: setTab, ENSEMBLES: ENSEMBLES,
                 showEntry: function (id) { entryId = id; setTab('learn'); var ws = document.getElementById('workspace'); ws.classList.remove('no-browser'); } };
})(globalThis.MD = globalThis.MD || {});
