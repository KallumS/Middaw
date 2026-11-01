/* The runtime generated JSFX code runs on. Every behaviour here mirrors
 * runtime/jsfx/jsfx.js, which is held to REAPER's own checks; the tests hold
 * this to that. */
#if !defined(__APPLE__) && !defined(_POSIX_C_SOURCE)
#define _POSIX_C_SOURCE 200809L
#endif
#include "jsfx_internal.h"
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <ctype.h>
#include <time.h>

/* --------------------------------------------------------------- gmem -- */
typedef struct { char name[128]; double *mem; } gmem_entry;
static gmem_entry gmems[16];
static int ngmems = 0;

static double *gmem_for(const char *name) {
    for (int i = 0; i < ngmems; i++) if (strcmp(gmems[i].name, name) == 0) return gmems[i].mem;
    if (ngmems >= 16) return NULL;
    strncpy(gmems[ngmems].name, name, 127);
    gmems[ngmems].mem = (double *)calloc(JSFX_GMEMWORDS, sizeof(double));
    return gmems[ngmems++].mem;
}
double jsfx_grd(jsfx_inst *S, double a) {
    if (!S->gmem) return 0;
    int64_t i = jsfx_index(a + JSFX_EPS);
    return (i >= 0 && i < JSFX_GMEMWORDS) ? S->gmem[i] : 0.0;
}
double jsfx_gwr(jsfx_inst *S, double a, double x) {
    if (!S->gmem) return x;
    int64_t i = jsfx_index(a + JSFX_EPS);
    if (i >= 0 && i < JSFX_GMEMWORDS) S->gmem[i] = x;
    return x;
}

int64_t jsfx_i64(double x) {
    double t = trunc(x);
    if (t > -9.2e18 && t < 9.2e18) return (int64_t)t;
    if (!isfinite(t)) return 0;
    double m = fmod(t, 18446744073709551616.0);
    if (m < 0) m += 18446744073709551616.0;
    return (int64_t)(uint64_t)m;
}

double jsfx_rand(jsfx_inst *S, double x) {
    S->rng = S->rng * 1664525u + 1013904223u;
    return (double)S->rng / 4294967296.0 * x;
}
void jsfx_seed(jsfx_inst *S, uint32_t seed) { S->rng = seed; }

/* ------------------------------------------------------------ strings -- */
static jsfx_str *str_slot(jsfx_inst *S, int64_t id, int create) {
    if (!S->strs) {
        if (!create) return NULL;
        S->strCap = 256;
        S->strs = (jsfx_str *)calloc((size_t)S->strCap, sizeof(jsfx_str));
            }
    uint64_t h = (uint64_t)id * 2654435761u;
    for (int k = 0; k < S->strCap; k++) {
        jsfx_str *e = &S->strs[(h + (uint64_t)k) % (uint64_t)S->strCap];
        if (e->used && e->id == id) return e;
        if (!e->used) {
            if (!create) return NULL;
            if (S->strCount * 2 >= S->strCap) {
                /* grow, rehash */
                jsfx_str *old = S->strs; int oldCap = S->strCap;
                S->strCap *= 2;
                S->strs = (jsfx_str *)calloc((size_t)S->strCap, sizeof(jsfx_str));
                S->strCount = 0;
                for (int i = 0; i < oldCap; i++) if (old[i].used) {
                    jsfx_str *n = str_slot(S, old[i].id, 1);
                    n->s = old[i].s; n->len = old[i].len; n->cap = old[i].cap;
                }
                free(old);
                return str_slot(S, id, 1);
            }
            e->id = id; e->s = NULL; e->len = 0; e->cap = 0; e->used = 1;
            S->strCount++;
            return e;
        }
    }
    return NULL;
}

const char *jsfx_str_get(jsfx_inst *S, double idd, int *len) {
    int64_t id = (int64_t)trunc(idd);
    if (id >= 10000 && id < 90000) {
        int i = (int)(id - 10000);
        const char *s = i < S->d->nstrings ? S->d->strings[i] : "";
        if (len) *len = (int)strlen(s);
        return s;
    }
    jsfx_str *e = str_slot(S, id, 0);
    if (!e || !e->s) { if (len) *len = 0; return ""; }
    if (len) *len = e->len;
    return e->s;
}

static double str_set(jsfx_inst *S, double idd, const char *s, int len) {
    int64_t id = (int64_t)trunc(idd);
    jsfx_str *e = str_slot(S, id, 1);
    if (!e) return idd;
    if (e->cap < len + 1) {
        /* grows, and keeps what it grew to: a string rewritten every block
         * stops allocating once it has been as long as it gets */
        int cap = len + 1 < 64 ? 64 : (len + 1) * 2;
        char *n = (char *)malloc((size_t)cap);
        if (!n) return idd;
        free(e->s);
        e->s = n; e->cap = cap;
    }
    memmove(e->s, s, (size_t)len);
    e->s[len] = 0;
    e->len = len;
    return idd;
}

double jsfx_strcpy(jsfx_inst *S, double dst, double src) {
    int len; const char *s = jsfx_str_get(S, src, &len);
    if (trunc(dst) == trunc(src)) return dst;
    /* src may be in the table that str_set can grow: copy it out first */
    char buf[1024];
    if (len < (int)sizeof buf) { memcpy(buf, s, (size_t)len); return str_set(S, dst, buf, len); }
    char *copy = (char *)malloc((size_t)len + 1);
    memcpy(copy, s, (size_t)len);
    str_set(S, dst, copy, len);
    free(copy);
    return dst;
}

/* JavaScript's String(x): the shortest digits that read back as x. */
int jsfx_js_number(double x, char *out, size_t cap) {
    if (x != x) return snprintf(out, cap, "NaN");
    if (isinf(x)) return snprintf(out, cap, x < 0 ? "-Infinity" : "Infinity");
    if (x == 0) return snprintf(out, cap, "0");
    char buf[40], digits[24]; int k = 0, e = 0;
    for (int p = 1; p <= 17; p++) {
        snprintf(buf, sizeof buf, "%.*e", p - 1, fabs(x));
        if (strtod(buf, NULL) == fabs(x)) break;
    }
    for (char *q = buf; *q && *q != 'e'; q++) if (isdigit((unsigned char)*q)) digits[k++] = *q;
    e = atoi(strchr(buf, 'e') + 1);
    while (k > 1 && digits[k - 1] == '0') k--;
    digits[k] = 0;
    int n = e + 1, o = 0;
    char s[64];
    if (x < 0) s[o++] = '-';
    if (k <= n && n <= 21) {
        memcpy(s + o, digits, (size_t)k); o += k;
        for (int i = 0; i < n - k; i++) s[o++] = '0';
    } else if (0 < n && n <= 21) {
        memcpy(s + o, digits, (size_t)n); o += n; s[o++] = '.';
        memcpy(s + o, digits + n, (size_t)(k - n)); o += k - n;
    } else if (-6 < n && n <= 0) {
        s[o++] = '0'; s[o++] = '.';
        for (int i = 0; i < -n; i++) s[o++] = '0';
        memcpy(s + o, digits, (size_t)k); o += k;
    } else {
        s[o++] = digits[0];
        if (k > 1) { s[o++] = '.'; memcpy(s + o, digits + 1, (size_t)(k - 1)); o += k - 1; }
        o += snprintf(s + o, sizeof s - (size_t)o, "e%c%d", n - 1 < 0 ? '-' : '+', abs(n - 1));
    }
    s[o] = 0;
    return snprintf(out, cap, "%s", s);
}

/* EEL2's sprintf as runtime/jsfx/jsfx.js does it; %s takes a string handle. */
double jsfx_sprintf(jsfx_inst *S, double dst, double fmtid, int nargs, const double *args) {
    int flen; const char *f = jsfx_str_get(S, fmtid, &flen);
    char out[8192]; int o = 0, vi = 0;
    for (int i = 0; i < flen && o < (int)sizeof(out) - 64; i++) {
        if (f[i] != '%') { out[o++] = f[i]; continue; }
        int j = i + 1;
        char flags[8] = {0}; int nf = 0;
        while (j < flen && strchr("-+ 0#", f[j]) && nf < 7) flags[nf++] = f[j++];
        int width = 0; while (j < flen && isdigit((unsigned char)f[j])) width = width * 10 + (f[j++] - '0');
        int prec = -1;
        if (j + 1 < flen && f[j] == '.' && isdigit((unsigned char)f[j + 1])) { j++; prec = 0; while (j < flen && isdigit((unsigned char)f[j])) prec = prec * 10 + (f[j++] - '0'); }
        if (j >= flen || !strchr("dixXfgecs%", f[j])) { out[o++] = f[i]; continue; }
        char conv = f[j];
        i = j;
        if (conv == '%') { out[o++] = '%'; continue; }
        double v = vi < nargs ? args[vi] : 0; vi++;
        char s[4096]; s[0] = 0;
        switch (conv) {
        case 'd': case 'i': jsfx_js_number(trunc(v), s, sizeof s); break;
        case 'x': snprintf(s, sizeof s, "%x", (unsigned)(uint32_t)jsfx_index(v)); break;
        case 'X': snprintf(s, sizeof s, "%X", (unsigned)(uint32_t)jsfx_index(v)); break;
        case 'f':
            if (!isfinite(v)) jsfx_js_number(v, s, sizeof s);
            else snprintf(s, sizeof s, "%.*f", prec < 0 ? 6 : prec, v);
            break;
        case 'e':
            if (!isfinite(v)) { jsfx_js_number(v, s, sizeof s); break; }
            snprintf(s, sizeof s, "%.*e", prec < 0 ? 6 : prec, v);
            { /* JavaScript writes e+5, not e+05 */
                char *ep = strchr(s, 'e');
                if (ep) { int ex = atoi(ep + 1); snprintf(ep, sizeof s - (size_t)(ep - s), "e%c%d", ex < 0 ? '-' : '+', abs(ex)); }
            }
            break;
        case 'g': {
            if (!isfinite(v)) { jsfx_js_number(v, s, sizeof s); break; }
            char t[64]; int p = prec < 0 ? 6 : (prec < 1 ? 1 : prec);
            snprintf(t, sizeof t, "%.*e", p - 1, v);
            jsfx_js_number(strtod(t, NULL), s, sizeof s);
            break;
        }
        case 'c': s[0] = (char)(jsfx_index(v) & 255); s[1] = 0; break;
        case 's': { int l; const char *x = jsfx_str_get(S, v, &l); snprintf(s, sizeof s, "%.*s", l, x); break; }
        }
        if (strchr(flags, '+') && conv != 's' && v >= 0) { memmove(s + 1, s, strlen(s) + 1); s[0] = '+'; }
        int sl = conv == 'c' ? 1 : (int)strlen(s);
        int left = strchr(flags, '-') != NULL, zero = strchr(flags, '0') != NULL && conv != 's';
        int pad = width > sl ? width - sl : 0;
        if (!left) for (int k = 0; k < pad && o < (int)sizeof(out) - 1; k++) out[o++] = zero ? '0' : ' ';
        for (int k = 0; k < sl && o < (int)sizeof(out) - 1; k++) out[o++] = s[k];
        if (left) for (int k = 0; k < pad && o < (int)sizeof(out) - 1; k++) out[o++] = ' ';
    }
    out[o] = 0;
    return str_set(S, dst, out, o);
}

/* match("pat*", str): * any run, ? any one character. */
static int glob(const char *p, int pl, const char *s, int sl, int ci) {
    if (pl == 0) return sl == 0;
    if (*p == '*') {
        for (int k = 0; k <= sl; k++) if (glob(p + 1, pl - 1, s + k, sl - k, ci)) return 1;
        return 0;
    }
    if (sl == 0) return 0;
    if (*p == '?' || (ci ? tolower((unsigned char)*p) == tolower((unsigned char)*s) : *p == *s)) return glob(p + 1, pl - 1, s + 1, sl - 1, ci);
    return 0;
}
double jsfx_match(jsfx_inst *S, int ci, double pat, double str) {
    int pl, sl;
    const char *p = jsfx_str_get(S, pat, &pl), *s = jsfx_str_get(S, str, &sl);
    return glob(p, pl, s, sl, ci) ? 1.0 : 0.0;
}

/* ------------------------------------------------------------ sliders -- */
static int slider_slot(jsfx_inst *S, double n) {
    int i = (int)trunc(n);
    if (i < 0 || i >= S->d->nsliderSlot) return -1;
    return S->d->sliderSlot[i];
}
double jsfx_slider_idx(jsfx_inst *S, double n) { int s = slider_slot(S, n); return s < 0 ? 0 : S->v[s]; }
double jsfx_set_slider_idx(jsfx_inst *S, double n, double v) { int s = slider_slot(S, n); if (s >= 0) S->v[s] = v; return v; }

/* --------------------------------------------------------------- MIDI -- */
double jsfx_midirecv(jsfx_inst *S) {
    if (S->midiInPos >= S->midiInCount) return 0;
    const jsfx_midi *e = &S->midiIn[S->midiInPos++];
    S->mr[0] = e->offset; S->mr[1] = e->data[0];
    S->mr[2] = e->len > 1 ? e->data[1] : 0; S->mr[3] = e->len > 2 ? e->data[2] : 0;
    return 1;
}
static void send(jsfx_inst *S, int offset, int len, int b1, int b2, int b3) {
    if (S->midiOutCount >= JSFX_MIDIOUT) return;
    jsfx_midi *m = &S->midiOut[S->midiOutCount++];
    m->offset = offset < 0 ? 0 : offset; m->len = len;
    m->data[0] = (uint8_t)b1; m->data[1] = (uint8_t)b2; m->data[2] = (uint8_t)b3;
}
double jsfx_midisend(jsfx_inst *S, double offset, double b1, double b2, double b3) {
    send(S, (int)trunc(offset), 3, (int)jsfx_i64(b1) & 255, (int)jsfx_i64(b2) & 127, (int)jsfx_i64(b3) & 127);
    return b1;
}
double jsfx_midisend3(jsfx_inst *S, double offset, double b1, double b23) {
    int64_t x = jsfx_i64(b23);
    return jsfx_midisend(S, offset, b1, (double)(x & 255), (double)((x >> 8) & 255));
}
double jsfx_midisend_buf(jsfx_inst *S, double offset, double buf, double len) {
    int n = (int)trunc(len);
    int b[3] = {0, 0, 0};
    for (int i = 0; i < n && i < 3; i++) b[i] = (int)jsfx_i64(jsfx_rd(S, buf + i)) & 255;
    send(S, (int)trunc(offset), n < 3 ? n : 3, b[0], b[1], b[2]);
    return len;
}

/* ---------------------------------------------------- serialize, files -- */
static void serial_push(jsfx_inst *S, int isString, double v, const char *s, int len) {
    if (S->serialCount >= S->serialCap) {
        S->serialCap = S->serialCap ? S->serialCap * 2 : 1024;
        S->serial = (jsfx_serial_item *)realloc(S->serial, sizeof(jsfx_serial_item) * (size_t)S->serialCap);
    }
    jsfx_serial_item *it = &S->serial[S->serialCount++];
    it->isString = isString; it->value = v; it->string = NULL;
    if (isString) { it->string = (char *)malloc((size_t)len + 1); memcpy(it->string, s, (size_t)len); it->string[len] = 0; }
}

static jsfx_file *handle(jsfx_inst *S, int h, jsfx_handle **o) {
    if (h <= 0 || h >= 64 || !S->open[h].file || S->open[h].file > S->nfiles) return NULL;
    *o = &S->open[h];
    return &S->files[S->open[h].file - 1];
}

double jsfx_file_var(jsfx_inst *S, double hd, double cur) {
    int h = (int)trunc(hd);
    if (h == 0 && S->serialMode) {
        if (S->serialMode == 1) { serial_push(S, 0, cur, NULL, 0); return cur; }
        if (S->serialPos >= S->serialCount) { S->serialPos++; return cur; }
        jsfx_serial_item *it = &S->serial[S->serialPos++];
        return it->isString ? cur : it->value;
    }
    jsfx_handle *o; jsfx_file *f = handle(S, h, &o);
    if (f && o->pos < f->count) return f->values[o->pos++];
    return cur;
}

double jsfx_file_riff(jsfx_inst *S, double hd) {
    int h = (int)trunc(hd);
    jsfx_handle *o; jsfx_file *f = handle(S, h, &o);
    S->riff[0] = f ? f->channels : 0; S->riff[1] = f ? f->rate : 0;
    return f ? 1 : 0;
}

void jsfx_add_file(jsfx_inst *S, const char *name, const float *data, int64_t frames, int channels, double rate) {
    if (S->nfiles >= S->capFiles) {
        S->capFiles = S->capFiles ? S->capFiles * 2 : 8;
        S->files = (jsfx_file *)realloc(S->files, sizeof(jsfx_file) * (size_t)S->capFiles);
    }
    jsfx_file *f = NULL;
    for (int i = 0; i < S->nfiles; i++) if (strcmp(S->files[i].name, name) == 0) {
        f = &S->files[i];
        free(f->values);
        break;
    }
    if (!f) {
        f = &S->files[S->nfiles++];
        size_t l = strlen(name);
        f->name = (char *)malloc(l + 1);
        memcpy(f->name, name, l + 1);
    }
    f->count = frames * channels;
    f->values = (double *)malloc(sizeof(double) * (size_t)(f->count ? f->count : 1));
    for (int64_t i = 0; i < f->count; i++) f->values[i] = data[i];
    f->channels = channels; f->rate = rate;
}

/* ---------------------------------------------------------- built-ins -- */
#define A(i) (nargs > (i) ? a[i] : 0.0)

double jsfx_b_memset(jsfx_inst *S, int nargs, const double *a) {
    double d = A(0), v = A(1), n = A(2);
    for (double i = 0; i < n && i < JSFX_MEMWORDS; i++) jsfx_wr(S, d + i, v);
    return d;
}
double jsfx_b_memcpy(jsfx_inst *S, int nargs, const double *a) {
    double d = A(0), s = A(1), nd = A(2);
    if (!(nd > 0)) return d;
    int64_t n = (int64_t)ceil(nd < JSFX_MEMWORDS ? nd : JSFX_MEMWORDS);
    /* as if through a copy: the regions may overlap */
    if (d <= s) for (int64_t i = 0; i < n; i++) jsfx_wr(S, d + (double)i, jsfx_rd(S, s + (double)i));
    else for (int64_t i = n - 1; i >= 0; i--) jsfx_wr(S, d + (double)i, jsfx_rd(S, s + (double)i));
    return d;
}
double jsfx_b_freembuf(jsfx_inst *S, int nargs, const double *a) { (void)S; return A(0); }
double jsfx_b_mem_set_values(jsfx_inst *S, int nargs, const double *a) { (void)S; (void)nargs; (void)a; return 0; }
double (*jsfx_clock)(void) = NULL;
double jsfx_b_time(jsfx_inst *S, int nargs, const double *a) {
    (void)S; (void)nargs; (void)a;
    if (jsfx_clock) return floor(1.7e9 + jsfx_clock() - 1000.0);
    return floor((double)time(NULL));
}
double jsfx_b_time_precise(jsfx_inst *S, int nargs, const double *a) {
    (void)S; (void)nargs; (void)a;
    if (jsfx_clock) return jsfx_clock();
    struct timespec ts; clock_gettime(CLOCK_MONOTONIC, &ts);
    return (double)ts.tv_sec + ts.tv_nsec / 1e9;
}
double jsfx_b_sliderchange(jsfx_inst *S, int nargs, const double *a) { (void)nargs; (void)a; S->sliderChanged = 1; return 0; }
double jsfx_b_slider_automate(jsfx_inst *S, int nargs, const double *a) { (void)nargs; (void)a; S->sliderChanged = 1; return 0; }
double jsfx_b_slider_show(jsfx_inst *S, int nargs, const double *a) { (void)S; (void)nargs; (void)a; return 0; }
double jsfx_b_strlen(jsfx_inst *S, int nargs, const double *a) { int l; jsfx_str_get(S, A(0), &l); return l; }
double jsfx_b_strcat(jsfx_inst *S, int nargs, const double *a) {
    int l1, l2; const char *x = jsfx_str_get(S, A(0), &l1), *y = jsfx_str_get(S, A(1), &l2);
    char buf[2048];
    char *n = l1 + l2 < (int)sizeof buf ? buf : (char *)malloc((size_t)l1 + (size_t)l2 + 1);
    memcpy(n, x, (size_t)l1); memcpy(n + l1, y, (size_t)l2);
    str_set(S, A(0), n, l1 + l2);
    if (n != buf) free(n);
    return A(0);
}
static int cmp(const char *x, int lx, const char *y, int ly, int ci) {
    for (int i = 0; i < lx && i < ly; i++) {
        int c1 = (unsigned char)x[i], c2 = (unsigned char)y[i];
        if (ci) { c1 = tolower(c1); c2 = tolower(c2); }
        if (c1 != c2) return c1 < c2 ? -1 : 1;
    }
    return lx < ly ? -1 : (lx > ly ? 1 : 0);
}
double jsfx_b_strcmp(jsfx_inst *S, int nargs, const double *a) {
    int l1, l2; const char *x = jsfx_str_get(S, A(0), &l1), *y = jsfx_str_get(S, A(1), &l2);
    return cmp(x, l1, y, l2, 0);
}
double jsfx_b_stricmp(jsfx_inst *S, int nargs, const double *a) {
    int l1, l2; const char *x = jsfx_str_get(S, A(0), &l1), *y = jsfx_str_get(S, A(1), &l2);
    return cmp(x, l1, y, l2, 1);
}
static double set_copy(jsfx_inst *S, double dst, const char *s, int len) {
    char buf[1024];
    if (len < (int)sizeof buf) { memcpy(buf, s, (size_t)len); return str_set(S, dst, buf, len); }
    char *n = (char *)malloc((size_t)len + 1);
    memcpy(n, s, (size_t)len);
    str_set(S, dst, n, len);
    free(n);
    return dst;
}
double jsfx_b_strncpy(jsfx_inst *S, int nargs, const double *a) {
    int l; const char *s = jsfx_str_get(S, A(1), &l);
    double nd = trunc(A(2)); int n = nd != nd ? 0 : (nd < 0 ? (int)fmax(0, l + nd) : (nd > l ? l : (int)nd));
    return set_copy(S, A(0), s, n);
}
double jsfx_b_strcpy_substr(jsfx_inst *S, int nargs, const double *a) {
    int l; const char *s = jsfx_str_get(S, A(1), &l);
    int off = (int)trunc(A(2));
    if (off < 0) { off = l + off; if (off < 0) off = 0; }
    if (off > l) off = l;
    int len = nargs > 3 ? (int)trunc(a[3]) : l - off;
    if (len < 0) len = 0;
    if (off + len > l) len = l - off;
    return set_copy(S, A(0), s + off, len);
}
double jsfx_b_str_getchar(jsfx_inst *S, int nargs, const double *a) {
    int l; const char *s = jsfx_str_get(S, A(0), &l);
    int i = (int)trunc(A(1)); if (i < 0) i += l;
    return (i >= 0 && i < l) ? (unsigned char)s[i] : 0;
}
double jsfx_b_str_setchar(jsfx_inst *S, int nargs, const double *a) {
    int l; const char *s = jsfx_str_get(S, A(0), &l);
    int i = (int)trunc(A(1)); if (i < 0) i += l;
    if (i >= 0 && i <= l) {
        int nl = i == l ? l + 1 : l;
        char buf[1024];
        char *n = nl < (int)sizeof buf ? buf : (char *)malloc((size_t)nl + 1);
        memcpy(n, s, (size_t)l);
        n[i] = (char)(int)trunc(A(2));
        str_set(S, A(0), n, nl);
        if (n != buf) free(n);
    }
    return A(2);
}
double jsfx_b_file_open(jsfx_inst *S, int nargs, const double *a) {
    int l; const char *name = jsfx_str_get(S, A(0), &l);
    for (int i = 0; i < S->nfiles; i++) if ((int)strlen(S->files[i].name) == l && memcmp(S->files[i].name, name, (size_t)l) == 0) {
        for (int h = 1; h < 64; h++) if (!S->open[h].file) { S->open[h].file = i + 1; S->open[h].pos = 0; return h; }
    }
    return -1;
}
double jsfx_b_file_close(jsfx_inst *S, int nargs, const double *a) { int h = (int)trunc(A(0)); if (h > 0 && h < 64) S->open[h].file = 0; return 0; }
double jsfx_b_file_rewind(jsfx_inst *S, int nargs, const double *a) { int h = (int)trunc(A(0)); if (h > 0 && h < 64) S->open[h].pos = 0; return 0; }
double jsfx_b_file_avail(jsfx_inst *S, int nargs, const double *a) {
    int h = (int)trunc(A(0));
    if (h == 0 && S->serialMode) return S->serialMode == 1 ? -1 : S->serialCount - S->serialPos;
    jsfx_handle *o; jsfx_file *f = handle(S, h, &o);
    return f ? (double)(f->count - o->pos) : 0;
}
double jsfx_b_file_text(jsfx_inst *S, int nargs, const double *a) { (void)S; (void)nargs; (void)a; return 0; }
double jsfx_b_file_mem(jsfx_inst *S, int nargs, const double *a) {
    int h = (int)trunc(A(0)); double addr = A(1); int64_t n = A(2) > 0 ? (int64_t)ceil(A(2) < JSFX_MEMWORDS ? A(2) : JSFX_MEMWORDS) : 0;
    if (h == 0 && S->serialMode) {
        if (S->serialMode == 1) { for (int64_t i = 0; i < n; i++) serial_push(S, 0, jsfx_rd(S, addr + (double)i), NULL, 0); }
        else for (int64_t j = 0; j < n; j++) {
            double v = 0;
            if (S->serialPos < S->serialCount) { jsfx_serial_item *it = &S->serial[S->serialPos++]; v = it->isString ? 0 : it->value; }
            else S->serialPos++;
            jsfx_wr(S, addr + (double)j, v);
        }
        return (double)n;
    }
    jsfx_handle *o; jsfx_file *f = handle(S, h, &o);
    if (!f) return 0;
    int64_t k = 0;
    for (; k < n && o->pos < f->count; k++) jsfx_wr(S, addr + (double)k, f->values[o->pos++]);
    return (double)k;
}
double jsfx_b_file_string(jsfx_inst *S, int nargs, const double *a) {
    int h = (int)trunc(A(0));
    if (h == 0 && S->serialMode) {
        if (S->serialMode == 1) { int l; const char *s = jsfx_str_get(S, A(1), &l); serial_push(S, 1, 0, s, l); }
        else if (S->serialPos < S->serialCount) {
            jsfx_serial_item *it = &S->serial[S->serialPos++];
            if (it->isString) set_copy(S, A(1), it->string, (int)strlen(it->string));
        } else S->serialPos++;
    }
    return 1;
}
double jsfx_b_export_buffer_to_project(jsfx_inst *S, int nargs, const double *a) { (void)S; (void)nargs; (void)a; return 0; }
double jsfx_b_get_host_placement(jsfx_inst *S, int nargs, const double *a) { (void)S; (void)nargs; (void)a; return 0; }
double jsfx_b_get_host_numchan(jsfx_inst *S, int nargs, const double *a) { (void)S; (void)nargs; (void)a; return 2; }
double jsfx_b_set_host_numchan(jsfx_inst *S, int nargs, const double *a) { (void)S; (void)nargs; (void)a; return 0; }
double jsfx_b_get_pin_mapping(jsfx_inst *S, int nargs, const double *a) { (void)S; (void)nargs; (void)a; return 0; }
double jsfx_b_set_pdc(jsfx_inst *S, int nargs, const double *a) { (void)S; (void)nargs; (void)a; return 0; }
double jsfx_b_printf(jsfx_inst *S, int nargs, const double *a) { (void)S; (void)nargs; (void)a; return 0; }
double jsfx_b_gfx_getchar(jsfx_inst *S, int nargs, const double *a) { (void)S; (void)nargs; (void)a; return 0; }

double jsfx_unknown(jsfx_inst *S, const char *name) { (void)S; (void)name; return 0; }

/* ----------------------------------------------------------- instance -- */
jsfx_inst *jsfx_new(const jsfx_desc *d, double srate) {
    jsfx_inst *S = (jsfx_inst *)calloc(1, sizeof(jsfx_inst));
    S->d = d;
    S->v = (double *)calloc((size_t)d->nvars + 16, sizeof(double));
    /* EEL2's 8M words: reserved, touched only where written */
    S->M = (double *)calloc(JSFX_MEMWORDS, sizeof(double));
    S->gmem = gmem_for(d->gmemName ? d->gmemName : "");
    S->srate = srate > 0 ? srate : 48000;
    S->rng = 22222;
    S->capFiles = 8;
    S->files = (jsfx_file *)calloc((size_t)S->capFiles, sizeof(jsfx_file));
    for (int i = 0; i < d->nsliders; i++) S->v[d->sliderSlot[d->sliders[i].index]] = d->sliders[i].def;
    return S;
}

void jsfx_free(jsfx_inst *S) {
    if (!S) return;
    free(S->v); free(S->M);
    if (S->strs) { for (int i = 0; i < S->strCap; i++) free(S->strs[i].s); free(S->strs); }
    jsfx_free_items(S->serial, S->serialCount);
    for (int i = 0; i < S->nfiles; i++) { free(S->files[i].name); free(S->files[i].values); }
    free(S->files);
    free(S);
}

static double run(jsfx_inst *S, int which) {
    double r = 0;
    for (int i = 0; i < S->d->nsections[which]; i++) r = S->d->sections[which][i](S);
    return r;
}

void jsfx_init(jsfx_inst *S, double srate) {
    const jsfx_desc *d = S->d;
    if (srate > 0) S->srate = srate;
    double keep[256];
    int n = d->nsliders < 256 ? d->nsliders : 256;
    for (int i = 0; i < n; i++) keep[i] = S->v[d->sliderSlot[d->sliders[i].index]];
    memset(S->v, 0, sizeof(double) * ((size_t)d->nvars + 16));
    /* EEL2's memory starts at zero: a fresh calloc is zero pages the system
     * only backs once written, where a memset would touch all 64 MB */
    if (S->initialised) { free(S->M); S->M = (double *)calloc(JSFX_MEMWORDS, sizeof(double)); }
    if (S->strs) { for (int i = 0; i < S->strCap; i++) { free(S->strs[i].s); S->strs[i].s = NULL; S->strs[i].cap = 0; S->strs[i].used = 0; } S->strCount = 0; }
    for (int i = 0; i < n; i++) S->v[d->sliderSlot[d->sliders[i].index]] = keep[i];
    S->v[d->s_srate] = S->srate;
    S->v[d->s_num_ch] = d->inPins > d->outPins ? d->inPins : d->outPins;
    if (S->v[d->s_tempo] == 0) S->v[d->s_tempo] = 120;
    if (S->v[d->s_ts_num] == 0) S->v[d->s_ts_num] = 4;
    if (S->v[d->s_ts_denom] == 0) S->v[d->s_ts_denom] = 4;
    S->midiOutCount = 0;
    run(S, 0);
    run(S, 1);
    S->sliderDirty = 0;
    S->initialised = 1;
}

void jsfx_set_slider(jsfx_inst *S, int index, double value) { jsfx_set_slider_idx(S, index, value); S->sliderDirty = 1; }
double jsfx_get_slider(jsfx_inst *S, int index) { return jsfx_slider_idx(S, index); }

void jsfx_set_time(jsfx_inst *S, double tempo, double playState, double beat, double seconds, double num, double den) {
    const jsfx_desc *d = S->d;
    if (!isnan(tempo)) S->v[d->s_tempo] = tempo;
    if (!isnan(playState)) S->v[d->s_play_state] = playState;
    if (!isnan(beat)) S->v[d->s_beat_position] = beat;
    if (!isnan(seconds)) S->v[d->s_play_position] = seconds;
    if (!isnan(num)) S->v[d->s_ts_num] = num;
    if (!isnan(den)) S->v[d->s_ts_denom] = den;
}

int jsfx_process(jsfx_inst *S, int n, const float *const *in, int nin, float *const *out, int nout,
                 const jsfx_midi *midi, int nmidi) {
    const jsfx_desc *d = S->d;
    if (!S->initialised) jsfx_init(S, 0);
    if (S->sliderDirty) { S->sliderDirty = 0; run(S, 1); }
    S->v[d->s_samplesblock] = n;
    S->midiIn = midi; S->midiInCount = nmidi; S->midiInPos = 0;
    S->midiOutCount = 0;
    run(S, 2);
    if (d->nsections[3]) {
        int nch = nin > nout ? nin : nout;
        if (nch < 2) nch = 2;
        if (nch > 64) nch = 64;
        for (int i = 0; i < n; i++) {
            for (int c = 0; c < nch; c++) S->v[d->s_spl[c]] = (c < nin && in && in[c]) ? in[c][i] : 0.0;
            run(S, 3);
            for (int c = 0; c < nout; c++) if (out && out[c]) out[c][i] = (float)S->v[d->s_spl[c]];
        }
    } else if (out && in) {
        for (int c = 0; c < nout && c < nin; c++) if (out[c] && in[c] && out[c] != in[c]) memcpy(out[c], in[c], sizeof(float) * (size_t)n);
    }
    /* MIDI the plug-in did not read passes through, as in REAPER */
    for (int r = S->midiInPos; r < S->midiInCount; r++) {
        if (S->midiOutCount >= JSFX_MIDIOUT) break;
        S->midiOut[S->midiOutCount++] = S->midiIn[r];
    }
    /* stable sort by offset */
    for (int i = 1; i < S->midiOutCount; i++) {
        jsfx_midi x = S->midiOut[i]; int j = i - 1;
        while (j >= 0 && S->midiOut[j].offset > x.offset) { S->midiOut[j + 1] = S->midiOut[j]; j--; }
        S->midiOut[j + 1] = x;
    }
    S->midiIn = NULL; S->midiInCount = 0;
    return S->midiOutCount;
}

const jsfx_midi *jsfx_midi_out(jsfx_inst *S) { return S->midiOut; }

static int var_slot(jsfx_inst *S, const char *name) {
    char low[256]; int i = 0;
    for (; name[i] && i < 255; i++) low[i] = (char)tolower((unsigned char)name[i]);
    low[i] = 0;
    for (int k = 0; k < S->d->nvars; k++) if (S->d->varnames[k] && strcmp(S->d->varnames[k], low) == 0) return k;
    return -1;
}
double jsfx_get_var(jsfx_inst *S, const char *name) { int s = var_slot(S, name); return s < 0 ? 0 : S->v[s]; }
void jsfx_set_var(jsfx_inst *S, const char *name, double value) { int s = var_slot(S, name); if (s >= 0) S->v[s] = value; }

int jsfx_call(jsfx_inst *S, const char *name, const double *args, int nargs, double *result) {
    for (int i = 0; i < S->d->nfuncs; i++) {
        const jsfx_func *f = &S->d->funcs[i];
        if (strcmp(f->name, name) != 0) continue;
        double a[16] = {0};
        for (int k = 0; k < nargs && k < 16; k++) a[k] = args[k];
        double r = f->fn(S, a);
        if (result) *result = r;
        return 1;
    }
    return 0;
}

int jsfx_serialize(jsfx_inst *S, jsfx_serial_item **items) {
    S->serial = NULL; S->serialCount = 0; S->serialCap = 0; S->serialPos = 0;
    S->serialMode = 1;
    run(S, 4);
    S->serialMode = 0;
    *items = S->serial;
    int n = S->serialCount;
    S->serial = NULL; S->serialCount = 0; S->serialCap = 0;
    return n;
}

void jsfx_deserialize(jsfx_inst *S, const jsfx_serial_item *items, int count) {
    if (!S->initialised) jsfx_init(S, 0);
    S->serial = (jsfx_serial_item *)items; S->serialCount = count; S->serialPos = 0;
    S->serialMode = 2;
    run(S, 4);
    S->serialMode = 0;
    S->serial = NULL; S->serialCount = 0;
    S->sliderDirty = 1;
}

void jsfx_free_items(jsfx_serial_item *items, int count) {
    if (!items) return;
    for (int i = 0; i < count; i++) free(items[i].string);
    free(items);
}

int jsfx_take_slider_change(jsfx_inst *S) { int c = S->sliderChanged; S->sliderChanged = 0; return c; }

double jsfx_mem(jsfx_inst *S, double addr) { return jsfx_rd(S, addr); }
double *jsfx_gmem(jsfx_inst *S) { return S->gmem; }
void jsfx_set_string(jsfx_inst *S, double id, const char *text) { str_set(S, id, text, (int)strlen(text)); }
const char *jsfx_get_string(jsfx_inst *S, double id) { return jsfx_str_get(S, id, NULL); }
