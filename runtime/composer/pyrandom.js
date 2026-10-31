/* Python's random.Random, bit for bit: the Mersenne Twister, Python's
 * seeding (an int, or a string through SHA-512 as version 2 does), and the
 * methods the composer calls - random, getrandbits, randrange, choice,
 * choices, uniform, gauss. The composer's output is a function of its seed,
 * so the same seed has to draw the same numbers here as in middaw/. */
(function (NS) {
  'use strict';

  // ----------------------------------------------------------- SHA-512 --
  var K = [
    '428a2f98d728ae22', '7137449123ef65cd', 'b5c0fbcfec4d3b2f', 'e9b5dba58189dbbc', '3956c25bf348b538', '59f111f1b605d019',
    '923f82a4af194f9b', 'ab1c5ed5da6d8118', 'd807aa98a3030242', '12835b0145706fbe', '243185be4ee4b28c', '550c7dc3d5ffb4e2',
    '72be5d74f27b896f', '80deb1fe3b1696b1', '9bdc06a725c71235', 'c19bf174cf692694', 'e49b69c19ef14ad2', 'efbe4786384f25e3',
    '0fc19dc68b8cd5b5', '240ca1cc77ac9c65', '2de92c6f592b0275', '4a7484aa6ea6e483', '5cb0a9dcbd41fbd4', '76f988da831153b5',
    '983e5152ee66dfab', 'a831c66d2db43210', 'b00327c898fb213f', 'bf597fc7beef0ee4', 'c6e00bf33da88fc2', 'd5a79147930aa725',
    '06ca6351e003826f', '142929670a0e6e70', '27b70a8546d22ffc', '2e1b21385c26c926', '4d2c6dfc5ac42aed', '53380d139d95b3df',
    '650a73548baf63de', '766a0abb3c77b2a8', '81c2c92e47edaee6', '92722c851482353b', 'a2bfe8a14cf10364', 'a81a664bbc423001',
    'c24b8b70d0f89791', 'c76c51a30654be30', 'd192e819d6ef5218', 'd69906245565a910', 'f40e35855771202a', '106aa07032bbd1b8',
    '19a4c116b8d2d0c8', '1e376c085141ab53', '2748774cdf8eeb99', '34b0bcb5e19b48a8', '391c0cb3c5c95a63', '4ed8aa4ae3418acb',
    '5b9cca4f7763e373', '682e6ff3d6b2b8a3', '748f82ee5defb2fc', '78a5636f43172f60', '84c87814a1f0ab72', '8cc702081a6439ec',
    '90befffa23631e28', 'a4506cebde82bde9', 'bef9a3f7b2c67915', 'c67178f2e372532b', 'ca273eceea26619c', 'd186b8c721c0c207',
    'eada7dd6cde0eb1e', 'f57d4f7fee6ed178', '06f067aa72176fba', '0a637dc5a2c898a6', '113f9804bef90dae', '1b710b35131c471b',
    '28db77f523047d84', '32caab7b40c72493', '3c9ebe0a15c9bebc', '431d67c49c100d4c', '4cc5d4becb3e42b6', '597f299cfc657e2a',
    '5fcb6fab3ad6faec', '6c44198c4a475817'].map(function (h) { return BigInt('0x' + h); });
  var M64 = (1n << 64n) - 1n;
  function rotr(x, n) { return ((x >> n) | (x << (64n - n))) & M64; }
  function sha512(bytes) {
    var H = ['6a09e667f3bcc908', 'bb67ae8584caa73b', '3c6ef372fe94f82b', 'a54ff53a5f1d36f1',
             '510e527fade682d1', '9b05688c2b3e6c1f', '1f83d9abfb41bd6b', '5be0cd19137e2179'].map(function (h) { return BigInt('0x' + h); });
    var msg = bytes.slice();
    var bitLen = BigInt(bytes.length) * 8n;
    msg.push(0x80);
    while (msg.length % 128 !== 112) msg.push(0);
    for (var i = 15; i >= 0; i--) msg.push(Number((bitLen >> BigInt(i * 8)) & 0xffn));
    for (var off = 0; off < msg.length; off += 128) {
      var W = [];
      for (var t = 0; t < 16; t++) {
        var w = 0n;
        for (var b = 0; b < 8; b++) w = (w << 8n) | BigInt(msg[off + t * 8 + b]);
        W.push(w);
      }
      for (t = 16; t < 80; t++) {
        var s0 = rotr(W[t - 15], 1n) ^ rotr(W[t - 15], 8n) ^ (W[t - 15] >> 7n);
        var s1 = rotr(W[t - 2], 19n) ^ rotr(W[t - 2], 61n) ^ (W[t - 2] >> 6n);
        W.push((W[t - 16] + s0 + W[t - 7] + s1) & M64);
      }
      var a = H[0], bb = H[1], c = H[2], d = H[3], e = H[4], f = H[5], g = H[6], h = H[7];
      for (t = 0; t < 80; t++) {
        var S1 = rotr(e, 14n) ^ rotr(e, 18n) ^ rotr(e, 41n);
        var ch = (e & f) ^ (~e & M64 & g);
        var t1 = (h + S1 + ch + K[t] + W[t]) & M64;
        var S0 = rotr(a, 28n) ^ rotr(a, 34n) ^ rotr(a, 39n);
        var maj = (a & bb) ^ (a & c) ^ (bb & c);
        var t2 = (S0 + maj) & M64;
        h = g; g = f; f = e; e = (d + t1) & M64; d = c; c = bb; bb = a; a = (t1 + t2) & M64;
      }
      H = [H[0] + a, H[1] + bb, H[2] + c, H[3] + d, H[4] + e, H[5] + f, H[6] + g, H[7] + h].map(function (x) { return x & M64; });
    }
    var out = [];
    H.forEach(function (x) { for (var i = 7; i >= 0; i--) out.push(Number((x >> BigInt(i * 8)) & 0xffn)); });
    return out;
  }
  function utf8(s) {
    var out = [];
    for (var i = 0; i < s.length; i++) {
      var c = s.codePointAt(i);
      if (c > 0xffff) i++;
      if (c < 0x80) out.push(c);
      else if (c < 0x800) out.push(0xc0 | (c >> 6), 0x80 | (c & 63));
      else if (c < 0x10000) out.push(0xe0 | (c >> 12), 0x80 | ((c >> 6) & 63), 0x80 | (c & 63));
      else out.push(0xf0 | (c >> 18), 0x80 | ((c >> 12) & 63), 0x80 | ((c >> 6) & 63), 0x80 | (c & 63));
    }
    return out;
  }

  // ---------------------------------------------------- the twister --
  var N = 624;
  function Random(seed) {
    this.mt = new Uint32Array(N);
    this.mti = N + 1;
    this.gaussNext = null;
    this.seed(seed);
  }
  Random.prototype.initGenrand = function (s) {
    var mt = this.mt;
    mt[0] = s >>> 0;
    for (var i = 1; i < N; i++) {
      var p = mt[i - 1] ^ (mt[i - 1] >>> 30);
      mt[i] = (Math.imul(1812433253, p) + i) >>> 0;
    }
    this.mti = N;
  };
  Random.prototype.initByArray = function (key) {
    var mt = this.mt;
    this.initGenrand(19650218);
    var i = 1, j = 0, k = Math.max(N, key.length);
    for (; k; k--) {
      var p = mt[i - 1] ^ (mt[i - 1] >>> 30);
      mt[i] = ((mt[i] ^ Math.imul(p, 1664525)) + key[j] + j) >>> 0;
      i++; j++;
      if (i >= N) { mt[0] = mt[N - 1]; i = 1; }
      if (j >= key.length) j = 0;
    }
    for (k = N - 1; k; k--) {
      p = mt[i - 1] ^ (mt[i - 1] >>> 30);
      mt[i] = ((mt[i] ^ Math.imul(p, 1566083941)) - i) >>> 0;
      i++;
      if (i >= N) { mt[0] = mt[N - 1]; i = 1; }
    }
    mt[0] = 0x80000000;
  };
  /* An int (any size, as a Number or BigInt) or a string, as Python seeds. */
  Random.prototype.seed = function (a) {
    this.gaussNext = null;
    var n;
    if (a === undefined || a === null) {
      // no seed: the time, as Python takes the OS's entropy
      n = BigInt(Date.now()) * 1000003n + BigInt(Math.floor(Math.random() * 4294967296));
    } else if (typeof a === 'string') {
      var bytes = utf8(a);
      var all = bytes.concat(sha512(bytes));
      n = 0n;
      for (var i = 0; i < all.length; i++) n = (n << 8n) | BigInt(all[i]);
    } else {
      n = BigInt(a);
    }
    if (n < 0n) n = -n;
    var key = [];
    while (n > 0n) { key.push(Number(n & 0xffffffffn)); n >>= 32n; }
    if (!key.length) key = [0];
    this.initByArray(key);
  };
  Random.prototype.genrand = function () {
    var mt = this.mt, y, kk;
    if (this.mti >= N) {
      for (kk = 0; kk < N - 397; kk++) {
        y = (mt[kk] & 0x80000000) | (mt[kk + 1] & 0x7fffffff);
        mt[kk] = mt[kk + 397] ^ (y >>> 1) ^ (y & 1 ? 0x9908b0df : 0);
      }
      for (; kk < N - 1; kk++) {
        y = (mt[kk] & 0x80000000) | (mt[kk + 1] & 0x7fffffff);
        mt[kk] = mt[kk + (397 - N)] ^ (y >>> 1) ^ (y & 1 ? 0x9908b0df : 0);
      }
      y = (mt[N - 1] & 0x80000000) | (mt[0] & 0x7fffffff);
      mt[N - 1] = mt[396] ^ (y >>> 1) ^ (y & 1 ? 0x9908b0df : 0);
      this.mti = 0;
    }
    y = mt[this.mti++];
    y ^= y >>> 11;
    y ^= (y << 7) & 0x9d2c5680;
    y ^= (y << 15) & 0xefc60000;
    y ^= y >>> 18;
    return y >>> 0;
  };
  Random.prototype.random = function () {
    var a = this.genrand() >>> 5, b = this.genrand() >>> 6;
    return (a * 67108864 + b) * (1 / 9007199254740992);
  };
  /* k up to 53 bits, as a Number. */
  Random.prototype.getrandbits = function (k) {
    if (k <= 0) return 0;
    if (k <= 32) return this.genrand() >>> (32 - k);
    // little-endian 32-bit words, the last one cut to what is left
    var r = 0, mul = 1, left = k;
    while (left > 0) {
      var w = this.genrand();
      if (left < 32) w = w >>> (32 - left);
      r += w * mul;
      mul *= 4294967296;
      left -= 32;
    }
    return r;
  };
  function bitLength(n) { var k = 0; while (n >= 1) { n = Math.floor(n / 2); k++; } return k; }
  Random.prototype.randbelow = function (n) {
    var k = bitLength(n);
    var r = this.getrandbits(k);
    while (r >= n) r = this.getrandbits(k);
    return r;
  };
  Random.prototype.randrange = function (start, stop) {
    if (stop === undefined) {
      if (start <= 0) throw new Error('empty range for randrange()');
      return this.randbelow(start);
    }
    var width = stop - start;
    if (width <= 0) throw new Error('empty range for randrange()');
    return start + this.randbelow(width);
  };
  Random.prototype.randint = function (a, b) { return this.randrange(a, b + 1); };
  Random.prototype.choice = function (seq) {
    if (!seq.length) throw new Error('Cannot choose from an empty sequence');
    return seq[this.randbelow(seq.length)];
  };
  /* choices(population, weights, k), as Python 3.9 with weights given. */
  Random.prototype.choices = function (population, weights, k) {
    k = k === undefined ? 1 : k;
    var n = population.length, out = [], i;
    if (!weights) {
      for (i = 0; i < k; i++) out.push(population[Math.floor(this.random() * n)]);
      return out;
    }
    var cum = [], acc = 0;
    for (i = 0; i < weights.length; i++) { acc += weights[i]; cum.push(acc); }
    var total = cum[cum.length - 1] + 0.0, hi = n - 1;
    for (i = 0; i < k; i++) {
      var x = this.random() * total, lo = 0, h = hi;
      while (lo < h) { var mid = (lo + h) >> 1; if (x < cum[mid]) h = mid; else lo = mid + 1; }
      out.push(population[lo]);
    }
    return out;
  };
  Random.prototype.uniform = function (a, b) { return a + (b - a) * this.random(); };
  Random.prototype.gauss = function (mu, sigma) {
    var z = this.gaussNext;
    this.gaussNext = null;
    if (z === null) {
      var x2pi = this.random() * 2 * Math.PI;
      var g2rad = Math.sqrt(-2.0 * Math.log(1.0 - this.random()));
      z = Math.cos(x2pi) * g2rad;
      this.gaussNext = Math.sin(x2pi) * g2rad;
    }
    return mu + z * sigma;
  };
  Random.prototype.shuffle = function (x) {
    for (var i = x.length - 1; i > 0; i--) {
      var j = this.randbelow(i + 1);
      var t = x[i]; x[i] = x[j]; x[j] = t;
    }
  };

  NS.Random = Random;
  NS.sha512 = sha512;
  NS.utf8 = utf8;
})(typeof module === 'object' && module.exports
  ? (module.exports = (globalThis.MiddawPyRandom = globalThis.MiddawPyRandom || {}))
  : (globalThis.MiddawPyRandom = globalThis.MiddawPyRandom || {}));
