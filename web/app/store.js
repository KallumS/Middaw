/* What Middaw remembers between sessions.
 *
 * The open project is saved as you work (in the browser), preferences too.
 * Things that belong to you rather than to a browser - the Battle Pass - go
 * to the local server (data/user/), falling back to the browser's own storage
 * when the page is opened without it.
 */
(function (MD) {
  'use strict';
  function lsGet(k) { try { return localStorage.getItem(k); } catch (e) { return null; } }
  function lsSet(k, v) { try { localStorage.setItem(k, v); return true; } catch (e) { return false; } }

  var prefs = {};
  try { prefs = JSON.parse(lsGet('middaw.prefs') || '{}') || {}; } catch (e) { prefs = {}; }

  MD.store = {
    pref: function (k, d) { return prefs[k] === undefined ? d : prefs[k]; },
    setPref: function (k, v) { prefs[k] = v; lsSet('middaw.prefs', JSON.stringify(prefs)); },
    autosave: function (project) { lsSet('middaw.project', JSON.stringify(project)); },
    restore: function () {
      try { var s = lsGet('middaw.project'); return s ? JSON.parse(s) : null; } catch (e) { return null; }
    },
    get: function (key) {
      return fetch('/api/store/' + encodeURIComponent(key)).then(function (r) {
        if (!r.ok || r.status === 204) throw new Error('no store');
        return r.json();
      }).then(function (d) { return d && typeof d.text === 'string' ? d.text : null; })
        .catch(function () { return lsGet('middaw.store.' + key); });
    },
    put: function (key, text) {
      lsSet('middaw.store.' + key, text);
      return fetch('/api/store/' + encodeURIComponent(key), { method: 'PUT', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ text: text }) }).catch(function () {});
    },
    readLua: function () { return null; },
    writeLua: function () {}
  };
})(globalThis.MD = globalThis.MD || {});
