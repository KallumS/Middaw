/* What Python does that JavaScript does differently, for the composer's port:
 * round() is half-to-even on a float's exact value, % takes the divisor's
 * sign, // floors, tuples compare in order, sorted() is stable on a key,
 * min() and max() keep the first of equals. */
(function (NS) {
  'use strict';

  var F64 = new Float64Array(1), U32 = new Uint32Array(F64.buffer);
  /* x with f decimals, rounded half to even on its exact binary value: what
   * Python's round(x, f) and '%.*f' both do. */
  function fixed(x, f) {
    if (!isFinite(x)) return String(x);
    var neg = x < 0 || Object.is(x, -0); F64[0] = Math.abs(x);
    var hi = U32[1], lo = U32[0], exp = (hi >>> 20) & 0x7ff;
    var mant = (BigInt(hi & 0xfffff) << 32n) | BigInt(lo);
    if (exp === 0) exp = 1; else mant |= 1n << 52n;
    var e = exp - 1075, D, sc;
    if (e >= 0) { D = mant << BigInt(e); sc = 0; } else { D = mant * (5n ** BigInt(-e)); sc = -e; }
    var q;
    if (f >= sc) q = D * (10n ** BigInt(f - sc));
    else {
      var div = 10n ** BigInt(sc - f); q = D / div; var r2 = (D % div) * 2n;
      if (r2 > div || (r2 === div && (q & 1n) === 1n)) q += 1n;
    }
    var s = q.toString();
    if (f > 0) { while (s.length <= f) s = '0' + s; s = s.slice(0, s.length - f) + '.' + s.slice(s.length - f); }
    return (neg ? '-' : '') + s;
  }
  function round(x, nd) {
    if (nd === undefined || nd === null) {
      var fl = Math.floor(x), d = x - fl;
      if (d < 0.5) return fl;
      if (d > 0.5) return fl + 1;
      return fl % 2 === 0 ? fl : fl + 1;
    }
    var v = Number(fixed(x, nd));
    return v;
  }
  function mod(a, b) {
    var r = a % b;
    if (r !== 0 && (b < 0) !== (r < 0)) r += b;
    return r;
  }
  function floordiv(a, b) {
    if (Number.isInteger(a) && Number.isInteger(b)) return Math.floor(a / b);
    var m = a % b, div = (a - m) / b;
    if (m && (b < 0) !== (m < 0)) div -= 1;
    var fd = Math.floor(div);
    if (div - fd > 0.5) fd += 1;
    return fd;
  }
  function divmod(a, b) { return [floordiv(a, b), mod(a, b)]; }
  function int(x) { return Math.trunc(x); }

  /* Python's ordering: numbers, strings by code point, booleans as 0/1,
   * arrays (tuples) element by element. */
  function cmp(a, b) {
    if (Array.isArray(a)) {
      for (var i = 0; i < a.length && i < b.length; i++) { var c = cmp(a[i], b[i]); if (c) return c; }
      return a.length - b.length;
    }
    if (typeof a === 'boolean') a = a ? 1 : 0;
    if (typeof b === 'boolean') b = b ? 1 : 0;
    if (typeof a === 'string' && typeof b === 'string') {
      var x = Array.from(a), y = Array.from(b);
      for (var k = 0; k < x.length && k < y.length; k++) {
        var p = x[k].codePointAt(0), q = y[k].codePointAt(0);
        if (p !== q) return p < q ? -1 : 1;
      }
      return x.length - y.length;
    }
    return a < b ? -1 : (a > b ? 1 : 0);
  }
  function sorted(arr, key, reverse) {
    var tagged = arr.map(function (v, i) { return { v: v, k: key ? key(v) : v, i: i }; });
    tagged.sort(function (a, b) { var c = cmp(a.k, b.k); if (reverse) c = -c; return c || a.i - b.i; });
    return tagged.map(function (t) { return t.v; });
  }
  function min(arr, key) {
    var best, bk, first = true;
    arr.forEach(function (v) { var k = key ? key(v) : v; if (first || cmp(k, bk) < 0) { best = v; bk = k; first = false; } });
    if (first) throw new Error('min() arg is an empty sequence');
    return best;
  }
  function max(arr, key) {
    var best, bk, first = true;
    arr.forEach(function (v) { var k = key ? key(v) : v; if (first || cmp(k, bk) > 0) { best = v; bk = k; first = false; } });
    if (first) throw new Error('max() arg is an empty sequence');
    return best;
  }
  function sum(arr) { var s = 0; for (var i = 0; i < arr.length; i++) s += arr[i]; return s; }
  function range(a, b, step) {
    if (b === undefined) { b = a; a = 0; }
    step = step || 1;
    var out = [];
    if (step > 0) for (var i = a; i < b; i += step) out.push(i);
    else for (var j = a; j > b; j += step) out.push(j);
    return out;
  }
  /* Ordered unique values, as list(dict.fromkeys(xs)). */
  function unique(xs) {
    var seen = new Set(), out = [];
    xs.forEach(function (x) { var k = typeof x === 'object' ? JSON.stringify(x) : x; if (!seen.has(k)) { seen.add(k); out.push(x); } });
    return out;
  }
  function islower(s) { return /[a-z]/.test(s) && s === s.toLowerCase(); }
  function isupper(s) { return /[A-Z]/.test(s) && s === s.toUpperCase(); }
  function rstrip(s, chars) { var i = s.length; while (i > 0 && chars.indexOf(s[i - 1]) >= 0) i--; return s.slice(0, i); }
  function count(s, ch) { return s.split(ch).length - 1; }
  /* An ordered dict keyed by anything: Python's dict, where a JavaScript
   * object would reorder number-like keys. */
  function Dict(entries) { this.m = new Map(); if (entries) entries.forEach(function (e) { this.set(e[0], e[1]); }, this); }
  Dict.key = function (k) { return Array.isArray(k) ? JSON.stringify(k) : k; };
  Dict.prototype.get = function (k, d) { var e = this.m.get(Dict.key(k)); return e === undefined ? d : e[1]; };
  Dict.prototype.has = function (k) { return this.m.has(Dict.key(k)); };
  Dict.prototype.set = function (k, v) { var kk = Dict.key(k); var e = this.m.get(kk); if (e) e[1] = v; else this.m.set(kk, [k, v]); return v; };
  Dict.prototype.setdefault = function (k, v) { return this.has(k) ? this.get(k) : this.set(k, v); };
  Dict.prototype.delete = function (k) { this.m.delete(Dict.key(k)); };
  Dict.prototype.keys = function () { return Array.from(this.m.values(), function (e) { return e[0]; }); };
  Dict.prototype.values = function () { return Array.from(this.m.values(), function (e) { return e[1]; }); };
  Dict.prototype.items = function () { return Array.from(this.m.values(), function (e) { return [e[0], e[1]]; }); };
  Object.defineProperty(Dict.prototype, 'size', { get: function () { return this.m.size; } });
  /* The keys of a plain object in the order Python's json would give them:
   * the order they were written in the file. */
  function items(obj) { return obj instanceof Dict ? obj.items() : Object.keys(obj || {}).map(function (k) { return [k, obj[k]]; }); }

  NS.fixed = fixed; NS.round = round; NS.mod = mod; NS.floordiv = floordiv; NS.divmod = divmod; NS.int = int;
  NS.cmp = cmp; NS.sorted = sorted; NS.min = min; NS.max = max; NS.sum = sum; NS.range = range; NS.unique = unique;
  NS.islower = islower; NS.isupper = isupper; NS.rstrip = rstrip; NS.count = count; NS.Dict = Dict; NS.items = items;
})(typeof module === 'object' && module.exports
  ? (module.exports = (globalThis.MiddawPy = globalThis.MiddawPy || {}))
  : (globalThis.MiddawPy = globalThis.MiddawPy || {}));
