/* The Battle Pass, built in: DAW Battle Pass's rules (bp_game.lua, bp_loot.lua,
 * bp_theory.lua), unchanged, fed by what you do in Middaw.
 *
 * Fifteen active minutes unlock a tier; editing, adding tracks, writing
 * notes and using ideas earn XP, levels and crates; coins buy permission
 * slips. The clock stops when you stop working. Progress belongs to you, not
 * to a song, and is kept on the local server (data/user/battlepass).
 */
(function (MD) {
  'use strict';
  var app = MD.app, U = MD.ui, L = globalThis.MiddawLua;
  var G = null, st = null, ss = null, lastInput = 0, playing = false, dirty = false, page = 'pass', pending = [];

  function nowSecs() { return performance.now() / 1000; }
  function epoch() { return Math.floor(Date.now() / 1000); }
  function call(name) { var a = Array.prototype.slice.call(arguments, 1); return L.first(L.call(L.index(G, name)).apply(null, a)); }
  function get(path) {
    var v = st;
    path.split('.').forEach(function (k) { v = v === undefined ? undefined : L.index(v, isNaN(+k) ? k : +k); });
    return v instanceof L.LuaTable ? L.toJS(v) : (v instanceof L.LFloat ? v.n : (typeof v === 'string' ? L.fromBytes(v) : v));
  }

  function start() {
    var P = MD.engines.battlePass();
    G = P.G;
    return MD.store.get('battlepass').then(function (text) {
      var saved = text ? call('deserialize', L.toBytes(text)) : undefined;
      st = saved || call('newState', epoch());
      L.call(L.index(G, 'clampState'))(st, epoch());
      ss = call('newSession', st, nowSecs(), epoch());
      call('refresh', st, ss, epoch(), new L.LuaTable());
      lastInput = nowSecs();
      setInterval(tick, 1000);
      setInterval(save, 30000);
      window.addEventListener('beforeunload', save);
      drawRing();
    }).catch(function (e) { console.error('Battle Pass', e); });
  }
  function save() {
    if (!st || !dirty) return;
    dirty = false;
    MD.store.put('battlepass', L.fromBytes(call('serialize', st)));
  }

  function tick() {
    if (!st) return;
    var signals = L.toLua({ input: nowSecs() - lastInput < 1.5, playing: MD.audio.isPlaying(), recording: !!MD.actions.recording(),
                            project: app.project().title || 'Untitled' });
    try {
      call('tick', st, ss, nowSecs(), epoch(), signals);
      call('refresh', st, ss, epoch(), new L.LuaTable());
      call('checkAchievements', st, ss);
    } catch (e) { console.error(e); }
    dirty = true;
    drain();
    drawRing();
    if (U.isSheetOpen() && sheetBody) renderSheet();
  }
  // Something happened: user input keeps the clock running.
  function input() { lastInput = nowSecs(); }
  var KINDS = { edit: 1, track: 1, item: 1, notes: 1, take: 1, marker: 1, idea: 1, fx: 1 };
  function event(kind, n, info) {
    if (!st) return;
    input();
    if (kind === 'discover') kind = 'edit';
    if (!KINDS[kind]) return;
    try { call('event', st, ss, kind, n || 1, info ? L.toLua(info) : undefined); } catch (e) { console.error(e); }
    dirty = true;
    drain();
  }

  // What the game wants celebrated, said once in the status line.
  function drain() {
    var list = L.index(ss, 'notices');
    if (!list || !list.arr.length) return;
    var said = null;
    list.arr.forEach(function (nt) {
      var n = L.toJS(nt), k = n.kind;
      if (k === 'tier') said = 'Battle Pass: tier ' + (get('pass.tier')) + ' unlocked.';
      else if (k === 'level') said = 'Level ' + get('level') + ' - a crate is waiting in Loot.';
      else if (k === 'quest') said = 'Quest done: ' + (n.text || n.name || '') + '. Claim it in the Battle Pass.';
      else if (k === 'toast' && n.text && !/XP/.test(n.sub || '')) said = n.text + (n.sub ? ' - ' + n.sub : '');
      else if (k === 'season') said = 'A new season of the Battle Pass has started.';
    });
    list.arr.length = 0;
    // Never over what you just did: the game waits for an empty status line,
    // and the toolbar button carries a mark until the pass is opened.
    if (said) {
      document.getElementById('pass').classList.add('news');
      if (document.getElementById('status').hidden) U.status(said);
    }
  }

  function drawRing() {
    var cv = document.getElementById('pass-ring');
    if (!cv || !st) return;
    var r = U.rem(), size = Math.round(1.6 * r), g = U.fit(cv, size, size);
    var secs = get('pass.secs') || 0, frac = secs / L.index(G, 'TIER_SECONDS');
    g.clearRect(0, 0, size, size);
    g.lineWidth = Math.max(2, size * 0.14);
    g.strokeStyle = U.css('--rule'); g.beginPath(); g.arc(size / 2, size / 2, size / 2 - g.lineWidth, 0, Math.PI * 2); g.stroke();
    g.strokeStyle = U.css('--ink'); g.beginPath(); g.arc(size / 2, size / 2, size / 2 - g.lineWidth, -Math.PI / 2, -Math.PI / 2 + frac * Math.PI * 2); g.stroke();
    var label = document.getElementById('pass-label');
    var mins = Math.ceil((L.index(G, 'TIER_SECONDS') - secs) / 60);
    label.textContent = 'Tier ' + get('pass.tier');
    document.getElementById('pass').title = 'Battle Pass: ' + mins + (mins === 1 ? ' minute' : ' minutes') + ' of work to the next tier';
  }

  // ------------------------------------------------------------ the sheet --
  var sheetBody = null, confirm = null;
  function open() {
    if (!st) return;
    document.getElementById('pass').classList.remove('news');
    U.sheet('Battle Pass', function (b) { sheetBody = b; renderSheet(); }, { wide: true, onClose: function () { sheetBody = null; confirm = null; } });
  }
  function act(label, fn) {
    try { fn(); } catch (e) { console.error(e); }
    dirty = true; drain(); drawRing(); renderSheet();
  }
  // Spending asks once more (DAW Battle Pass 0015): the button says so and waits.
  function sure(id, label, fn) {
    if (confirm === id) return U.button('Click Again to ' + label, function () { confirm = null; act(label, fn); }, { class: 'primary' });
    return U.button(label, function () { confirm = id; renderSheet(); });
  }
  function renderSheet() {
    if (!sheetBody) return;
    U.clear(sheetBody);
    var tabs = U.el('div', { class: 'tabs', role: 'tablist' }, [['pass', 'Pass'], ['quests', 'Quests'], ['loot', 'Loot'], ['shop', 'Shop'], ['stats', 'Stats']].map(function (t) {
      return U.el('button', { type: 'button', role: 'tab', 'aria-selected': String(page === t[0]), onclick: function () { page = t[0]; confirm = null; renderSheet(); } }, [t[1]]);
    }));
    sheetBody.appendChild(tabs);
    var box = U.el('div', {});
    sheetBody.appendChild(box);
    var secs = get('pass.secs') || 0, T = L.index(G, 'TIER_SECONDS');
    if (page === 'pass') {
      var season = L.fromBytes(L.first(L.call(L.index(MD.engines.battlePass().L, 'seasonName'))(get('pass.season'))) || '');
      box.appendChild(U.el('p', { class: 'prose', text: season + ': tier ' + get('pass.tier') + '. ' + Math.ceil((T - secs) / 60) + ' active minutes to the next.' }));
      box.appendChild(U.el('p', { class: 'note-line', text: 'Level ' + get('level') + ', ' + Math.round(get('xp')) + ' of ' + call('levelNeed', get('level')) + ' XP. ' + Math.round(get('coins')) + ' coins.' }));
      var mins = Math.floor((get('stats.active') || 0) / 60);
      box.appendChild(U.el('p', { class: 'note-line', text: 'Today you have worked ' + Math.floor(((get('days') || {})[L.fromBytes(call('dayKey', epoch()))] || 0) / 60) + ' minutes; ' + mins + ' in all.' }));
      if (call('checkinAvailable', st, epoch())) box.appendChild(U.button('Check In for Today', function () { act('Check In', function () { call('checkin', st, ss, epoch()); }); }, { class: 'primary' }));
    } else if (page === 'quests') {
      ['daily', 'weekly'].forEach(function (scope) {
        box.appendChild(U.el('h4', { text: scope === 'daily' ? 'Today' : 'This Week' }));
        var qs = get(scope + '.quests') || [];
        (Array.isArray(qs) ? qs : Object.values(qs)).forEach(function (q, i) {
          var progress = Math.min(q.goal || 1, Math.round(q.have || q.progress || 0));
          var row = U.el('div', { class: 'rowline' }, [U.el('span', { text: (q.text || q.name || 'Quest') + '  ' }), U.el('span', { class: 'dim', text: progress + ' / ' + (q.goal || 1) })]);
          if (q.done && !q.claimed) row.appendChild(U.button('Claim', function () { act('Claim', function () { call('claimQuest', st, ss, scope, i + 1); }); }, { class: 'primary' }));
          else if (q.claimed) row.appendChild(U.el('span', { class: 'dim', text: 'Claimed' }));
          box.appendChild(row);
        });
      });
    } else if (page === 'loot') {
      var crates = get('inv.crates') || [], names = L.toJS(L.index(MD.engines.battlePass().L, 'RARITY')) || [];
      box.appendChild(U.el('h4', { text: 'Crates' }));
      var any = false;
      (Array.isArray(crates) ? crates : Object.values(crates)).forEach(function (n, i) {
        if (!n) return; any = true;
        box.appendChild(U.el('div', { class: 'rowline' }, [U.el('span', { text: (names[i] ? names[i].name : 'Crate') + ' Crate × ' + n }),
          U.button('Open', function () { act('Open', function () { call('openCrate', st, ss, i + 1); }); })]));
      });
      if (!any) box.appendChild(U.el('p', { class: 'note-line', text: 'No crates yet. Every level gives one.' }));
      var passes = get('inv.passes') || [];
      passes = Array.isArray(passes) ? passes : Object.values(passes);
      if (passes.length) {
        box.appendChild(U.el('h4', { text: 'Passes' }));
        passes.forEach(function (ps) {
          box.appendChild(U.el('div', { class: 'rowline' }, [U.el('span', { text: ps.name || ps.id }), sure('redeem-' + (ps.uid || ps.id), 'Redeem', function () { call('redeem', st, ss, ps.uid || ps.id, epoch()); })]));
        });
      }
      box.appendChild(U.el('h4', { text: 'Ideas' }));
      var ideas = MD.pass.ideas();
      if (!ideas.length) box.appendChild(U.el('p', { class: 'note-line', text: 'Ideas you win appear here, and in the browser’s Ideas.' }));
      ideas.forEach(function (idea) {
        box.appendChild(U.el('div', { class: 'rowline' }, [U.el('span', { text: idea.title + (idea.detail ? ' - ' + idea.detail : '') }),
          U.button(idea.midi ? 'Put in the Song' : 'Use', function () { useIdea(idea); U.closeSheet(); })]));
      });
    } else if (page === 'shop') {
      var shop = L.toJS(L.index(G, 'SHOP')) || [];
      shop = Array.isArray(shop) ? shop : Object.values(shop).filter(function (x) { return x && x.id; });
      box.appendChild(U.el('p', { class: 'note-line', text: Math.round(get('coins')) + ' coins to spend.' }));
      var cards = U.el('div', { class: 'cards' });
      shop.forEach(function (item) {
        var afford = get('coins') >= item.price;
        cards.appendChild(U.el('div', { class: 'card' }, [U.el('strong', { text: item.name }), U.el('span', { class: 'd', text: item.desc || '' }),
          U.el('span', { class: 'd', text: item.price + ' coins' }),
          afford ? sure('buy-' + item.id, 'Buy', function () { call('buy', st, ss, item.id); }) : U.button('Buy', null, { disabled: true })]));
      });
      box.appendChild(cards);
    } else {
      var s = get('stats') || {};
      var dl = U.el('dl', { class: 'facts' });
      [['Active time', Math.round((s.active || 0) / 60) + ' minutes'], ['Longest session', Math.round((s.longest || 0) / 60) + ' minutes'],
       ['Sessions', s.sessions], ['Edits', s.edits], ['Tracks made', s.tracks], ['Notes written', Math.round(s.notes || 0)],
       ['Ideas used', s.ideasUsed], ['Crates opened', s.crates], ['Tiers unlocked', s.tiers]].forEach(function (r) {
        dl.appendChild(U.el('dt', { text: r[0] })); dl.appendChild(U.el('dd', { text: String(r[1] || 0) }));
      });
      box.appendChild(dl);
    }
  }

  // Ideas won from crates and tiers, the ones that can become notes first.
  function ideas() {
    if (!st) return [];
    var vault = get('vault') || [];
    vault = Array.isArray(vault) ? vault : Object.values(vault);
    return vault.filter(function (v) { return v && v.type === 'idea'; }).map(function (v) {
      return { uid: v.uid, title: (v.name || 'Idea') + ': ' + (v.text || ''), detail: v.sub || '', midi: !!(v.data && (v.data.block || v.data.number)), raw: v };
    }).reverse();
  }
  function useIdea(idea) {
    var v = idea.raw, d = v.data || {};
    if (d.block) MD.actions.insertBlock(d.block, v.name);
    else if (d.number) { MD.generate.open('good-idea'); U.status('Good Idea number ' + d.number + ': set it as the idea number and press Generate.'); }
    else if (d.bpm && v.kind === 'seed') { app.commit('Use a Song Seed', function (q) { q.tempo = d.bpm; }); U.status(v.text + ' - ' + (v.sub || '')); }
    else U.status(v.text + (v.sub ? ' - ' + v.sub : ''));
    try { call('ideaUsed', st, ss, v.uid); } catch (e) {}
    dirty = true; drain();
  }

  MD.pass = { start: start, event: event, input: input, open: open, ideas: ideas, useIdea: useIdea };
})(globalThis.MD = globalThis.MD || {});
