#!/usr/bin/env node
/* The family's JSFX, translated to C for the native app.
 *
 *   node tools/jsfx2c.js            -> mac/Sources/CJSFX/devices/*.c
 *   node tools/jsfx2c.js --check    fails if those files are out of date
 *
 * The same parser as runtime/jsfx/jsfx.js and the same rules: every construct
 * below mirrors one in that file's Compiler, so a device behaves the same in
 * both. Where JavaScript fixes the order operands are evaluated in and C does
 * not, operands with side effects are evaluated into locals first, in order.
 *
 * The generated files are checked in and never edited: fix a device in its own
 * repository, sync family/devices/, and run this again. */
'use strict';
const fs = require('fs');
const path = require('path');
const J = require(path.join(__dirname, '..', 'runtime', 'jsfx', 'jsfx.js'));

const ROOT = path.join(__dirname, '..');
const SRC = path.join(ROOT, 'family', 'devices');
const OUT = path.join(ROOT, 'mac', 'Sources', 'CJSFX', 'devices');

const DEVICES = [
  ['autocc', 'AutoCC.jsfx'],
  ['instrument_creator', 'Instrument-Creator.jsfx'],
  ['midi_production_center', 'MIDI_Production_Center.jsfx'],
  ['midi_evolver', 'Midi Evolver.jsfx'],
  ['reverberator', 'Reverberator.jsfx'],
  ['transient_shuffler', 'TransientShuffler.jsfx']
];

// ------------------------------------------------------------ helpers ----
function num(v) {
  if (Number.isNaN(v)) return 'NAN';
  if (!isFinite(v)) return v < 0 ? '(-INFINITY)' : 'INFINITY';
  let s = String(Math.abs(v));
  if (/^\d+$/.test(s)) s += '.0';
  else if (/e/.test(s) && !/\./.test(s.split('e')[0])) s = s.replace('e', '.0e');
  return (v < 0 || Object.is(v, -0)) ? '(-' + s + ')' : s;
}

function cstr(s) {
  const bytes = Buffer.from(String(s), 'utf8');
  let out = '"';
  for (const b of bytes) {
    if (b === 0x22) out += '\\"';
    else if (b === 0x5c) out += '\\\\';
    else if (b >= 0x20 && b < 0x7f && b !== 0x3f) out += String.fromCharCode(b);   // no ? (trigraphs)
    else out += '\\' + b.toString(8).padStart(3, '0');
  }
  return out + '"';
}

function cname(s) { return s.replace(/[^a-z0-9_]/gi, (c) => '_' + c.charCodeAt(0).toString(16) + '_'); }

const MATH = {
  sin: 'sin', cos: 'cos', tan: 'tan', asin: 'asin', acos: 'acos', atan: 'atan', atan2: 'atan2',
  sqrt: 'jsfx_sqrt', exp: 'exp', log: 'log', log10: 'log10', abs: 'fabs', floor: 'floor', ceil: 'ceil',
  min: 'jsfx_min', max: 'jsfx_max', pow: 'jsfx_pow', sign: 'jsfx_sign', invsqrt: 'jsfx_invsqrt',
  sqr: 'jsfx_sqr', rand: 'jsfx_rand', exp2: 'jsfx_exp2'
};
const ARITY = { atan2: 2, pow: 2 };
const BUILTINS = ['memset', 'memcpy', 'freembuf', 'mem_set_values', 'time', 'time_precise', 'sliderchange',
  'slider_automate', 'slider_show', 'strlen', 'strcat', 'strcmp', 'stricmp', 'strncpy', 'strcpy_substr',
  'str_getchar', 'str_setchar', 'file_open', 'file_close', 'file_rewind', 'file_avail', 'file_text',
  'file_mem', 'file_string', 'export_buffer_to_project', 'get_host_placement', 'get_host_numchan',
  'set_host_numchan', 'get_pin_mapping', 'set_pdc', 'printf', 'gfx_getchar'];
const COMPOUND = { '+=': '+', '-=': '-', '*=': '*', '/=': '/', '%=': '%', '^=': '^', '|=': '|', '&=': '&', '~=': '~', '<<=': '<<', '>>=': '>>' };

function hasControl(n) {
  if (!n || typeof n !== 'object') return false;
  if (n.k === 'call' && (n.name === 'loop' || n.name === 'while')) return true;
  for (const key in n) {
    const c = n[key];
    if (Array.isArray(c)) { for (const x of c) if (hasControl(x)) return true; }
    else if (c && typeof c === 'object' && c.k && hasControl(c)) return true;
  }
  return false;
}

// Whether evaluating n can change anything another operand reads.
function impure(n) {
  if (!n) return false;
  switch (n.k) {
    case 'num': case 'strlit': case 'nstr': case 'tmpstr': case 'var': case 'raw': return false;
    case 'seq': return n.items.some(impure);
    case 'if': return impure(n.c) || impure(n.a) || impure(n.b);
    case 'logic': case 'bin': return impure(n.a) || impure(n.b);
    case 'un': return impure(n.a);
    case 'index': return impure(n.base) || impure(n.idx);
    case 'call':
      if ((MATH[n.name] && n.name !== 'rand') || n.name === 'slider') return n.args.some(impure);
      return true;
  }
  return true;
}

function T(e) { return 'jsfx_T(' + e + ')'; }

// --------------------------------------------------------- compiler ----
class CCompiler {
  constructor() {
    this.slots = { __count: 0 };
    this.names = [];
    this.funcs = {};
    this.compiled = {};
    this.order = [];          // compiled functions, in order: {fn, cn}
    this.funcCode = [];
    this.strConsts = [];
    this.named = {};
    this.nnamed = 0;
    this.temps = 0;
    this.q = 0;
  }
  slot(name) {
    let s = this.slots[name];
    if (s === undefined) { s = this.slots.__count++; this.slots[name] = s; this.names[s] = name; }
    return s;
  }
  temp() { this.temps++; return 't' + this.temps; }
  local() { this.q++; return '_q' + this.q; }
  tempDecl() {
    if (!this.temps) return '';
    const names = [];
    for (let i = 1; i <= this.temps; i++) names.push('t' + i + ' = 0.0');
    return ' double ' + names.join(', ') + ';';
  }

  compileSection(code, firstLine, cn) {
    const ast = J.parseEel(J.lexEel(code, firstLine), this.funcs);
    const saved = this.temps;
    this.temps = 0;
    const body = this.stmts(ast, null, true, 'r');
    const temps = this.tempDecl();
    this.temps = saved;
    return 'static double ' + cn + '(jsfx_inst *S) { double *const v = S->v; (void)v; double r = 0.0;' + temps + ' ' + body + ' return r; }';
  }

  ref(name, ctx) {
    if (ctx) {
      const pi = ctx.fn.params.indexOf(name);
      if (pi >= 0) return 'p' + pi;
      if (ctx.fn.locals.indexOf(name) >= 0) return 'v[' + this.slot(ctx.fn.name + '::' + name) + ']';
    }
    return 'v[' + this.slot(name) + ']';
  }

  stmts(n, ctx, want, target) {
    if (n.k === 'seq') {
      if (!n.items.length) return want ? target + ' = 0.0;' : '';
      let out = '';
      for (let i = 0; i < n.items.length; i++) out += this.stmts(n.items[i], ctx, want && i === n.items.length - 1, target);
      return out;
    }
    if (n.k === 'call' && n.name === 'loop') {
      const cnt = this.temp(), ii = this.temp();
      let s = cnt + ' = jsfx_min(JSFX_MAXLOOP, trunc(' + this.expr(n.args[0], ctx) + ')); ';
      if (want) s += target + ' = 0.0; ';
      s += 'for (' + ii + ' = 0.0; ' + ii + ' < ' + cnt + '; ' + ii + '++) {' + (n.args[1] ? this.stmts(n.args[1], ctx, want, target) : '') + '}';
      return s;
    }
    if (n.k === 'call' && n.name === 'while') {
      const guard = this.temp(), r = this.temp();
      if (n.args.length >= 2) {
        return guard + ' = 0.0; ' + (want ? target + ' = 0.0; ' : '') + 'while (fabs(' + this.expr(n.args[0], ctx) + ') >= JSFX_EPS && ' + guard + '++ < JSFX_MAXLOOP) {' +
          this.stmts(n.args[1], ctx, want, target) + '}';
      }
      return guard + ' = 0.0; do {' + this.stmts(n.args[0], ctx, true, r) + (want ? target + ' = ' + r + ';' : '') +
        '} while (fabs(' + r + ') >= JSFX_EPS && ++' + guard + ' < JSFX_MAXLOOP);';
    }
    if (n.k === 'if' && hasControl(n)) {
      let o = 'if (fabs(' + this.expr(n.c, ctx) + ') >= JSFX_EPS) {' + this.stmts(n.a, ctx, want, target) + '}';
      if (n.b) o += ' else {' + this.stmts(n.b, ctx, want, target) + '}';
      else if (want) o += ' else { ' + target + ' = 0.0; }';
      return o;
    }
    const e = this.expr(n, ctx);
    return (want ? target + ' = ' + e : '(void)(' + e + ')') + ';';
  }

  // Operands in JavaScript's order: into locals first when any has an effect.
  ordered(nodes, ctx, build) {
    const codes = nodes.map((x) => (x === undefined ? null : this.expr(x, ctx)));
    const effect = nodes.some((x) => x !== undefined && impure(x));
    if (!effect || nodes.length < 2) return build(codes);
    const names = [], decl = [];
    codes.forEach((c) => {
      if (c === null) { names.push(null); return; }
      const nm = this.local(); names.push(nm); decl.push('double ' + nm + ' = ' + c + '; ');
    });
    return '({ ' + decl.join('') + build(names) + '; })';
  }

  expr(n, ctx) {
    if (hasControl(n) && (n.k === 'seq' || n.k === 'if' || (n.k === 'call' && (n.name === 'loop' || n.name === 'while')))) {
      return '({ double rr = 0.0; ' + this.stmts(n, ctx, true, 'rr') + ' rr; })';
    }
    switch (n.k) {
      case 'raw': return n.code;
      case 'num': return num(n.v);
      case 'strlit': return num(this.strConst(n.v));
      case 'nstr': return num(this.namedStr(n.v));
      case 'tmpstr': return num(200000 + n.id);
      case 'var': return n.name === 'gmem' ? 'NAN' : this.ref(n.name, ctx);
      case 'seq': {
        if (!n.items.length) return '0.0';
        const last = n.items.length - 1;
        return '(' + n.items.map((x, i) => (i < last ? '(void)(' + this.expr(x, ctx) + ')' : this.expr(x, ctx))).join(', ') + ')';
      }
      case 'if':
        return '(' + T(this.expr(n.c, ctx)) + ' ? ' + this.expr(n.a, ctx) + ' : ' + (n.b ? this.expr(n.b, ctx) : '0.0') + ')';
      case 'logic': {
        const a = T(this.expr(n.a, ctx)), b = T(this.expr(n.b, ctx));
        return '((' + a + (n.op === '&&' ? ' && ' : ' || ') + b + ') ? 1.0 : 0.0)';
      }
      case 'un':
        if (n.op === '!') return '(' + T(this.expr(n.a, ctx)) + ' ? 0.0 : 1.0)';
        if (n.op === '-') return '(-' + this.expr(n.a, ctx) + ')';
        return this.expr(n.a, ctx);
      case 'bin': return this.ordered([n.a, n.b], ctx, (x) => this.binary(n.op, x[0], x[1]));
      case 'index': return this.memRead(n, ctx);
      case 'assign': return this.assignment(n, ctx);
      case 'call': return this.call(n, ctx);
    }
    throw new J.EelError('cannot compile ' + n.k);
  }

  binary(op, a, b) {
    switch (op) {
      case '+': return '(' + a + ' + ' + b + ')';
      case '-': return '(' + a + ' - ' + b + ')';
      case '*': return '(' + a + ' * ' + b + ')';
      case '/': return '(' + a + ' / ' + b + ')';
      case '%': return 'jsfx_mod(' + a + ', ' + b + ')';
      case '^': return 'jsfx_pow(' + a + ', ' + b + ')';
      case '<<': return 'jsfx_shl(' + a + ', ' + b + ')';
      case '>>': return 'jsfx_shr(' + a + ', ' + b + ')';
      case '|': return 'jsfx_bor(' + a + ', ' + b + ')';
      case '&': return 'jsfx_band(' + a + ', ' + b + ')';
      case '~': return 'jsfx_bxor(' + a + ', ' + b + ')';
      case '==': return 'jsfx_eq(' + a + ', ' + b + ')';
      case '!=': return '(1.0 - jsfx_eq(' + a + ', ' + b + '))';
      case '===': return '(' + a + ' == ' + b + ' ? 1.0 : 0.0)';
      case '!==': return '(' + a + ' != ' + b + ' ? 1.0 : 0.0)';
      case '<': case '>': case '<=': case '>=': return '(' + a + ' ' + op + ' ' + b + ' ? 1.0 : 0.0)';
    }
    throw new J.EelError('bad operator ' + op);
  }

  strConst(s) {
    let i = this.strConsts.indexOf(s);
    if (i < 0) { i = this.strConsts.length; this.strConsts.push(s); }
    return 10000 + i;
  }
  namedStr(name) {
    if (this.named[name] === undefined) this.named[name] = 90000 + this.nnamed++;
    return this.named[name];
  }

  address(n, ctx) {
    if (n.base.k === 'var' && n.base.name === 'gmem') return { gmem: true, addr: this.expr(n.idx, ctx), impure: impure(n.idx) };
    const imp = impure(n.base) || impure(n.idx);
    if (n.idx.k === 'num' && n.idx.v === 0) return { gmem: false, addr: this.expr(n.base, ctx), impure: imp };
    return { gmem: false, addr: this.ordered([n.base, n.idx], ctx, (x) => '(' + x[0] + ' + ' + x[1] + ')'), impure: imp };
  }
  memRead(n, ctx) {
    const a = this.address(n, ctx);
    return (a.gmem ? 'jsfx_grd(S, ' : 'jsfx_rdz(S, ') + a.addr + ')';
  }

  assignment(n, ctx) {
    const lhs = n.lhs, rhsImpure = impure(n.rhs);
    const rhs = this.expr(n.rhs, ctx);
    const op = COMPOUND[n.op];
    if (lhs.k === 'var') {
      const r = this.ref(lhs.name, ctx);
      if (n.op === '=') return '(' + r + ' = ' + rhs + ')';
      if (!rhsImpure) return '(' + r + ' = ' + this.binary(op, r, rhs) + ')';
      const c = this.local(), x = this.local();
      return '({ double ' + c + ' = ' + r + '; double ' + x + ' = ' + rhs + '; ' + r + ' = ' + this.binary(op, c, x) + '; })';
    }
    if (lhs.k === 'index') {
      const a = this.address(lhs, ctx);
      const rd = a.gmem ? 'jsfx_grd' : 'jsfx_rd', wr = a.gmem ? 'jsfx_gwr' : 'jsfx_wr';
      const t = this.local(), x = this.local();
      if (n.op === '=') {
        if (!rhsImpure && !a.impure) return wr + '(S, ' + a.addr + ', ' + rhs + ')';
        return '({ double ' + t + ' = ' + a.addr + '; double ' + x + ' = ' + rhs + '; ' + wr + '(S, ' + t + ', ' + x + '); })';
      }
      const c = this.local();
      return '({ double ' + t + ' = ' + a.addr + '; double ' + c + ' = ' + rd + '(S, ' + t + '); double ' + x + ' = ' + rhs + '; ' +
        wr + '(S, ' + t + ', ' + this.binary(op, c, x) + '); })';
    }
    if (lhs.k === 'if') {
      if (n.op !== '=') throw new J.EelError('compound assignment to a conditional is not supported');
      const tv = this.local();
      const asg = (side) => (side ? this.assignment({ k: 'assign', op: '=', lhs: side, rhs: { k: 'raw', code: tv } }, ctx) : '0.0');
      return '({ double ' + tv + ' = ' + rhs + '; ' + T(this.expr(lhs.c, ctx)) + ' ? ' + asg(lhs.a) + ' : ' + asg(lhs.b) + '; })';
    }
    if (lhs.k === 'nstr' || lhs.k === 'strlit') return 'jsfx_strcpy(S, ' + this.expr(lhs, ctx) + ', ' + rhs + ')';
    if (lhs.k === 'call' && lhs.name === 'slider') {
      const s = this.local(), x = this.local();
      const idx = 'double ' + s + ' = ' + this.expr(lhs.args[0], ctx) + '; ';
      if (n.op === '=') return '({ ' + idx + 'double ' + x + ' = ' + rhs + '; jsfx_set_slider_idx(S, ' + s + ', ' + x + '); })';
      const c = this.local();
      return '({ ' + idx + 'double ' + c + ' = jsfx_slider_idx(S, ' + s + '); double ' + x + ' = ' + rhs + '; jsfx_set_slider_idx(S, ' + s + ', ' + this.binary(op, c, x) + '); })';
    }
    if (lhs.k === 'seq' && lhs.items.length) {
      const head = lhs.items.slice(0, -1).map((x) => '(void)(' + this.expr(x, ctx) + ')');
      return '(' + head.concat([this.assignment({ k: 'assign', op: n.op, lhs: lhs.items[lhs.items.length - 1], rhs: n.rhs }, ctx)]).join(', ') + ')';
    }
    throw new J.EelError('cannot assign to ' + lhs.k);
  }

  lvalue(n, ctx) { return n && n.k === 'var' ? this.ref(n.name, ctx) : null; }

  // Every argument evaluated in order into an array, for the built-ins.
  arrayCall(args, ctx, minimum, build) {
    const n = Math.max(args.length, minimum);
    if (!n) return build('0', 'NULL');
    const a = this.local();
    let s = '({ double ' + a + '[' + n + '] = {0}; ';
    args.forEach((x, i) => { s += a + '[' + i + '] = ' + this.expr(x, ctx) + '; '; });
    return s + build(String(args.length), a) + '; })';
  }

  call(n, ctx) {
    const name = n.name, args = n.args;
    if (MATH[name]) {
      if (name === 'min' || name === 'max') {
        if (!args.length) return name === 'min' ? 'INFINITY' : '(-INFINITY)';
        return this.ordered(args, ctx, (x) => x.reduce((acc, c) => (acc === null ? c : MATH[name] + '(' + acc + ', ' + c + ')'), null));
      }
      if (name === 'rand') return this.ordered(args, ctx, (x) => 'jsfx_rand(S, ' + (x.length ? x[0] : '1.0') + ')');
      const want = ARITY[name] || 1;
      return this.ordered(args, ctx, (x) => {
        const used = [];
        for (let i = 0; i < want; i++) used.push(x[i] === undefined || x[i] === null ? 'NAN' : x[i]);
        return MATH[name] + '(' + used.join(', ') + ')';
      });
    }
    switch (name) {
      case 'midirecv': {
        const lv = args.map((x) => this.lvalue(x, ctx));
        const sets = [];
        for (let i = 0; i < lv.length; i++) {
          if (!lv[i]) continue;
          const src = lv.length >= 4 ? (i < 4 ? 'S->mr[' + i + ']' : 'NAN') : (i === 2 ? '(S->mr[2] + S->mr[3] * 256.0)' : 'S->mr[' + i + ']');
          sets.push(lv[i] + ' = ' + src);
        }
        return '(jsfx_midirecv(S) ? (' + (sets.length ? sets.join(', ') + ', ' : '') + 'S->mr[1]) : 0.0)';
      }
      case 'midisend':
        if (args.length >= 4) return this.ordered(args.slice(0, 4), ctx, (x) => 'jsfx_midisend(S, ' + x.join(', ') + ')');
        return this.ordered([args[0], args[1], args[2]], ctx, (x) => 'jsfx_midisend3(S, ' + x.map((c) => c || '0.0').join(', ') + ')');
      case 'midisend_buf': case 'midisyx':
        return this.ordered([args[0], args[1], args[2]], ctx, (x) => 'jsfx_midisend_buf(S, ' + x.map((c) => c || '0.0').join(', ') + ')');
      case 'file_var': {
        const fv = this.lvalue(args[1], ctx);
        if (!fv) return this.ordered([args[0], args[1]], ctx, (x) => 'jsfx_file_var(S, ' + x.map((c) => c || '0.0').join(', ') + ')');
        const h = this.local();
        return '({ double ' + h + ' = ' + (args[0] ? this.expr(args[0], ctx) : '0.0') + '; ' + fv + ' = jsfx_file_var(S, ' + h + ', ' + fv + '); })';
      }
      case 'file_riff': {
        const nc = this.lvalue(args[1], ctx), fr = this.lvalue(args[2], ctx), t = this.local();
        return '({ double ' + t + ' = jsfx_file_riff(S, ' + (args[0] ? this.expr(args[0], ctx) : '0.0') + '); ' +
          (nc ? nc + ' = S->riff[0]; ' : '') + (fr ? fr + ' = S->riff[1]; ' : '') + t + '; })';
      }
      case 'slider': return 'jsfx_slider_idx(S, ' + (args[0] ? this.expr(args[0], ctx) : '0.0') + ')';
      case 'loop': case 'while':
        return '({ double rr = 0.0; ' + this.stmts(n, ctx, true, 'rr') + ' rr; })';
      case 'match': case 'matchi': {
        const call = this.ordered([args[0], args[1]], ctx, (x) => 'jsfx_match(S, ' + (name === 'matchi' ? 1 : 0) + ', ' + x.map((c) => c || '0.0').join(', ') + ')');
        const refs = args.slice(2).map((x) => this.lvalue(x, ctx)).filter(Boolean);
        if (args.length <= 2) return call;
        const m = this.local();
        // runtime/jsfx/jsfx.js fills no captures: a match leaves them NaN
        return '({ double ' + m + ' = ' + call + '; ' + m + ' != 0 ? (' + refs.map((r) => r + ' = NAN, ').join('') + '1.0) : 0.0; })';
      }
      case 'strcpy':
        return this.ordered([args[0], args[1]].concat(args.slice(2)), ctx, (x) => 'jsfx_strcpy(S, ' + (x[0] || '0.0') + ', ' + (x[1] || '0.0') + ')');
      case 'sprintf':
        return this.arrayCall(args, ctx, 2, (cnt, a) => 'jsfx_sprintf(S, ' + a + '[0], ' + a + '[1], ' + Math.max(0, args.length - 2) + ', ' + a + ' + 2)');
    }
    if (this.funcs[name]) return this.userCall(this.funcs[name], args, ctx);
    if (name.indexOf('.') > 0) {
      const base = name.slice(name.lastIndexOf('.') + 1);
      if (this.funcs[base]) return this.userCall(this.funcs[base], args, ctx);
    }
    if (/^gfx_|^mouse_/.test(name)) return '(' + args.map((x) => '(void)(' + this.expr(x, ctx) + '), ').join('') + '0.0)';
    if (BUILTINS.indexOf(name) >= 0) return this.arrayCall(args, ctx, 0, (cnt, a) => 'jsfx_b_' + name + '(S, ' + cnt + ', ' + a + ')');
    return '(' + args.map((x) => '(void)(' + this.expr(x, ctx) + '), ').join('') + 'jsfx_unknown(S, ' + cstr(name) + '))';
  }

  ensure(fn) {
    const cn = 'F_' + cname(fn.name);
    if (this.compiled[fn.name]) return cn;
    this.compiled[fn.name] = true;
    const saved = this.temps;
    this.temps = 0;
    const body = this.stmts(fn.body, { fn: fn }, true, 'r');
    const temps = this.tempDecl();
    this.temps = saved;
    const params = ['jsfx_inst *S'].concat(fn.params.map((_, i) => 'double p' + i));
    this.funcCode.push('static double ' + cn + '(' + params.join(', ') + ') { double *const v = S->v; (void)v; double r = 0.0;' + temps + ' ' + body + ' return r; }');
    this.order.push({ fn: fn, cn: cn });
    return cn;
  }

  userCall(fn, args, ctx) {
    if (args.length !== fn.params.length && !(args.length === 1 && fn.params.length === 0)) {
      throw new J.EelError(fn.name + '() takes ' + fn.params.length + ' arguments, given ' + args.length);
    }
    const cn = this.ensure(fn);
    const used = args.slice(0, fn.params.length);
    return this.ordered(used, ctx, (x) => cn + '(' + ['S'].concat(x).join(', ') + ')');
  }
}

// ------------------------------------------------------------ a device ----
function translate(id, file) {
  const text = fs.readFileSync(path.join(SRC, file), 'utf8');
  const parsed = J.parseFile(text, (n) => fs.readFileSync(path.join(SRC, n), 'utf8'));
  const C = new CCompiler();
  ['srate', 'samplesblock', 'tempo', 'play_state', 'play_position', 'beat_position', 'ts_num', 'ts_denom',
   'num_ch', 'trigger', 'pdc_delay', 'pdc_bot_ch', 'pdc_top_ch', 'pdc_midi', 'ext_noinit', 'ext_nodenorm',
   'ext_midi_bus', 'midi_bus', 'gfx_ext_retina'].forEach((n) => C.slot(n));
  for (let c = 0; c < 64; c++) C.slot('spl' + c);
  for (let s = 1; s <= 64; s++) C.slot('slider' + s);
  parsed.sliders.forEach((sl) => C.slot(sl.variable));

  const order = ['init', 'slider', 'block', 'sample', 'serialize'];
  const sections = {};
  order.forEach((name) => {
    sections[name] = parsed.sections[name].map((part, i) => {
      const cn = 'sec_' + name + '_' + i;
      return { cn: cn, code: C.compileSection(part.code, part.line, cn) };
    });
  });
  // The plug-in's own functions, so the host can call them (a device's
  // buttons), as runtime/jsfx/jsfx.js's eval() sees them: every section's.
  const own = Object.keys(C.funcs);
  parsed.sections.gfx.forEach((part) => { try { J.parseEel(J.lexEel(part.code, part.line), C.funcs); } catch (e) { /* not run */ } });
  const skipped = [];
  own.forEach((name) => {
    try { C.ensure(C.funcs[name]); } catch (e) { skipped.push(name + ': ' + e.message); C.compiled[name] = false; }
  });

  const gmem = (/gmem=(\S+)/.exec(parsed.options) || [])[1] || '';
  const sliderSlot = [];
  for (let i = 0; i <= 64; i++) {
    const sl = parsed.sliders.find((s) => s.index === i);
    sliderSlot.push(sl ? C.slots[sl.variable] : (i >= 1 ? C.slots['slider' + i] : -1));
  }
  const L = [];
  L.push('/* Generated by tools/jsfx2c.js from family/devices/' + file + '. Do not edit. */');
  L.push('#include "../jsfx_internal.h"');
  L.push('#pragma clang diagnostic ignored "-Wunused-variable"');
  L.push('#pragma clang diagnostic ignored "-Wunused-value"');
  L.push('#pragma clang diagnostic ignored "-Wunused-but-set-variable"');
  L.push('#pragma clang diagnostic ignored "-Wunused-function"');
  L.push('#pragma clang diagnostic ignored "-Wgnu-statement-expression"');
  L.push('#pragma clang diagnostic ignored "-Wgnu-statement-expression-from-macro-expansion"');
  L.push('#pragma clang diagnostic ignored "-Wparentheses-equality"');
  L.push('#pragma clang diagnostic ignored "-Wunknown-warning-option"');
  L.push('');
  // prototypes first: functions call each other in any order
  C.order.forEach((f) => L.push('static double ' + f.cn + '(' + ['jsfx_inst *S'].concat(f.fn.params.map((_, i) => 'double p' + i)).join(', ') + ');'));
  L.push('');
  C.funcCode.forEach((c) => L.push(c));
  L.push('');
  order.forEach((name) => sections[name].forEach((s) => L.push(s.code)));
  L.push('');
  const callable = C.order.filter((f) => f.fn.params.length <= 16);
  callable.forEach((f) => {
    const a = f.fn.params.map((_, i) => 'a[' + i + ']');
    L.push('static double W_' + f.cn.slice(2) + '(jsfx_inst *S, const double *a) { (void)a; return ' + f.cn + '(' + ['S'].concat(a).join(', ') + '); }');
  });
  L.push('');
  const arr = (type, name, items) => 'static ' + type + ' ' + name + '[] = {' + (items.length ? items.join(', ') : '0') + '};';
  L.push(arr('const char *const', 'strings', C.strConsts.map(cstr)));
  const varnames = [];
  for (let i = 0; i < C.slots.__count; i++) varnames.push(cstr(C.names[i]));
  L.push(arr('const char *const', 'varnames', varnames));
  parsed.sliders.forEach((sl) => { if (sl.names) L.push(arr('const char *const', 'names_' + sl.index, sl.names.map((x) => cstr(x.trim())))); });
  L.push('static const jsfx_slider sliders[] = {' + (parsed.sliders.length ? parsed.sliders.map((sl) =>
    '{' + [sl.index, cstr(sl.variable), num(sl.def), num(sl.min), num(sl.max), num(sl.step), cstr(sl.name), sl.hidden ? 1 : 0,
      sl.names ? sl.names.length : 0, sl.names ? 'names_' + sl.index : 'NULL',
      sl.shape ? (sl.shape.kind === 'log' ? 1 : 2) : 0, sl.shape && sl.shape.value !== null ? num(sl.shape.value) : 'NAN'].join(', ') + '}').join(',\n  ') : '{0}') + '};');
  L.push(arr('const int', 'sliderSlot', sliderSlot.map(String)));
  order.forEach((name) => L.push(arr('const jsfx_section_fn', 'sections_' + name, sections[name].map((s) => s.cn))));
  L.push('static const jsfx_func funcs[] = {' + (callable.length ? callable.map((f) => '{' + cstr(f.fn.name) + ', ' + f.fn.params.length + ', W_' + f.cn.slice(2) + '}').join(',\n  ') : '{0}') + '};');
  const s = (n) => C.slots[n];
  L.push('const jsfx_desc jsfx_device_' + id + ' = {');
  L.push('  .id = ' + cstr(id) + ', .desc = ' + cstr(parsed.desc) + ',');
  L.push('  .nvars = ' + C.slots.__count + ', .varnames = varnames,');
  L.push('  .nsliders = ' + parsed.sliders.length + ', .sliders = sliders, .sliderSlot = sliderSlot,');
  L.push('  .nsections = {' + order.map((n) => sections[n].length).join(', ') + '},');
  L.push('  .sections = {' + order.map((n) => 'sections_' + n).join(', ') + '},');
  L.push('  .nstrings = ' + C.strConsts.length + ', .strings = strings, .nnamed = ' + C.nnamed + ',');
  L.push('  .nfuncs = ' + callable.length + ', .funcs = funcs,');
  L.push('  .gmemName = ' + cstr(gmem) + ', .inPins = ' + parsed.inPins.length + ', .outPins = ' + parsed.outPins.length + ',');
  L.push('  .s_srate = ' + s('srate') + ', .s_samplesblock = ' + s('samplesblock') + ', .s_tempo = ' + s('tempo') + ', .s_play_state = ' + s('play_state') +
    ', .s_play_position = ' + s('play_position') + ', .s_beat_position = ' + s('beat_position') + ', .s_ts_num = ' + s('ts_num') +
    ', .s_ts_denom = ' + s('ts_denom') + ', .s_num_ch = ' + s('num_ch') + ',');
  const spl = [];
  for (let c = 0; c < 64; c++) spl.push(s('spl' + c));
  L.push('  .s_spl = {' + spl.join(', ') + '}');
  L.push('};');
  return { code: L.join('\n') + '\n', skipped: skipped };
}

function registry() {
  const L = ['/* Generated by tools/jsfx2c.js. Do not edit. */', '#include "../jsfx_internal.h"', '#include <string.h>', ''];
  DEVICES.forEach(([id]) => L.push('extern const jsfx_desc jsfx_device_' + id + ';'));
  L.push('static const jsfx_desc *const all[] = {' + DEVICES.map(([id]) => '&jsfx_device_' + id).join(', ') + '};');
  L.push('int jsfx_count(void) { return ' + DEVICES.length + '; }');
  L.push('const jsfx_desc *jsfx_at(int i) { return i >= 0 && i < ' + DEVICES.length + ' ? all[i] : NULL; }');
  L.push('const jsfx_desc *jsfx_find(const char *id) {');
  L.push('    for (int i = 0; i < ' + DEVICES.length + '; i++) if (strcmp(all[i]->id, id) == 0) return all[i];');
  L.push('    return NULL;');
  L.push('}');
  return L.join('\n') + '\n';
}

function main() {
  const check = process.argv.includes('--check');
  const files = {};
  DEVICES.forEach(([id, file]) => {
    const r = translate(id, file);
    files[id + '.c'] = r.code;
    r.skipped.forEach((s) => console.error(file + ': not callable: ' + s));
  });
  files['registry.c'] = registry();
  let stale = 0;
  if (!check) fs.mkdirSync(OUT, { recursive: true });
  for (const name of Object.keys(files)) {
    const p = path.join(OUT, name);
    const old = fs.existsSync(p) ? fs.readFileSync(p, 'utf8') : null;
    if (old === files[name]) continue;
    if (check) { console.error('out of date: ' + path.relative(ROOT, p)); stale++; }
    else fs.writeFileSync(p, files[name]);
  }
  if (check && stale) { console.error('run: node tools/jsfx2c.js'); process.exit(1); }
}

if (require.main === module) main();
module.exports = { translate: translate, DEVICES: DEVICES };
