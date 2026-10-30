/* What the code tools/jsfx2c.js generates sees: an instance's insides, and
 * the helpers every EEL2 operator and built-in compiles to. */
#ifndef JSFX_INTERNAL_H
#define JSFX_INTERNAL_H

#include "include/jsfx_rt.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    char *name;
    double *values;
    int64_t count;
    int channels;
    double rate;
} jsfx_file;

typedef struct { int file; int64_t pos; } jsfx_handle;   /* file is index + 1, 0 when closed */

typedef struct { int64_t id; char *s; int len, cap; int used; } jsfx_str;

struct jsfx_inst {
    const jsfx_desc *d;
    double *v;
    double *M;
    double *gmem;
    double srate;
    /* MIDI */
    const jsfx_midi *midiIn;
    int midiInCount, midiInPos;
    jsfx_midi midiOut[JSFX_MIDIOUT];
    int midiOutCount;
    double mr[4];
    /* strings: an open-addressed table of id -> text */
    jsfx_str *strs;
    int strCap, strCount;
    double riff[2];
    double matchOut[8];
    /* @serialize */
    int serialMode;                  /* 0 none, 1 write, 2 read */
    jsfx_serial_item *serial;
    int serialCount, serialCap, serialPos;
    /* files the host has handed over (samples) */
    jsfx_file *files;
    int nfiles, capFiles;
    jsfx_handle open[64];            /* handle -> file; 0 is @serialize */
    int sliderDirty, sliderChanged, initialised;
    uint32_t rng;
};

/* ---------------------------------------------------- generated code uses */
static inline int64_t jsfx_index(double x) {
    /* JavaScript's (x | 0): truncate, wrap to 32 bits. */
    if (x > -2147483648.0 && x < 2147483648.0) return (int64_t)(int32_t)x;
    if (!isfinite(x)) return 0;
    double m = fmod(trunc(x), 4294967296.0);
    if (m < 0) m += 4294967296.0;
    return (int64_t)(int32_t)(uint32_t)m;
}
static inline double jsfx_rd(jsfx_inst *S, double a) {
    int64_t i = jsfx_index(a + JSFX_EPS);
    return (i >= 0 && i < JSFX_MEMWORDS) ? S->M[i] : 0.0;
}
/* A plain read, as JavaScript's (M[i] || 0): NaN and -0 read as 0. */
static inline double jsfx_rdz(jsfx_inst *S, double a) {
    double x = jsfx_rd(S, a);
    return (x != x || x == 0) ? 0.0 : x;
}
static inline double jsfx_wr(jsfx_inst *S, double a, double x) {
    int64_t i = jsfx_index(a + JSFX_EPS);
    if (i >= 0 && i < JSFX_MEMWORDS) S->M[i] = x;
    return x;
}
double jsfx_grd(jsfx_inst *S, double a);
double jsfx_gwr(jsfx_inst *S, double a, double x);

static inline double jsfx_T(double x) { return fabs(x) >= JSFX_EPS; }
static inline double jsfx_min(double a, double b) { return (a != a || b != b) ? NAN : (a < b ? a : b); }
static inline double jsfx_max(double a, double b) { return (a != a || b != b) ? NAN : (a > b ? a : b); }
static inline double jsfx_sqrt(double x) { return sqrt(fabs(x)); }
static inline double jsfx_sign(double x) { return x > 0 ? 1.0 : (x < 0 ? -1.0 : 0.0); }
static inline double jsfx_invsqrt(double x) { return 1.0 / sqrt(x); }
static inline double jsfx_sqr(double x) { return x * x; }
/* JavaScript's Math.pow, which differs from C's at 1^NaN and (-1)^Infinity. */
static inline double jsfx_pow(double a, double b) {
    if (b != b) return NAN;
    if (fabs(a) == 1.0 && isinf(b)) return NAN;
    return pow(a, b);
}
static inline double jsfx_exp2(double x) { return jsfx_pow(2.0, x); }
double jsfx_rand(jsfx_inst *S, double x);
static inline double jsfx_mod(double a, double b) {
    double ib = trunc(fabs(b));
    return ib != 0 ? fmod(trunc(fabs(a)), ib) : 0.0;
}
int64_t jsfx_i64(double x);
static inline double jsfx_shl(double a, double b) { return (double)(int64_t)((uint64_t)jsfx_i64(a) << (jsfx_i64(b) & 63)); }
static inline double jsfx_shr(double a, double b) { return (double)(jsfx_i64(a) >> (jsfx_i64(b) & 63)); }
static inline double jsfx_bor(double a, double b) { return (double)(jsfx_i64(a) | jsfx_i64(b)); }
static inline double jsfx_band(double a, double b) { return (double)(jsfx_i64(a) & jsfx_i64(b)); }
static inline double jsfx_bxor(double a, double b) { return (double)(jsfx_i64(a) ^ jsfx_i64(b)); }
static inline double jsfx_eq(double a, double b) { return fabs(a - b) < JSFX_EPS ? 1.0 : 0.0; }

double jsfx_slider_idx(jsfx_inst *S, double n);
double jsfx_set_slider_idx(jsfx_inst *S, double n, double v);
double jsfx_midirecv(jsfx_inst *S);
double jsfx_midisend(jsfx_inst *S, double offset, double b1, double b2, double b3);
double jsfx_midisend3(jsfx_inst *S, double offset, double b1, double b23);
double jsfx_midisend_buf(jsfx_inst *S, double offset, double buf, double len);
double jsfx_file_var(jsfx_inst *S, double h, double cur);
double jsfx_file_riff(jsfx_inst *S, double h);
double jsfx_match(jsfx_inst *S, int ci, double pat, double str);
/* The built-ins: jsfx_b_<name>(S, nargs, args). */
#define JSFX_BUILTINS(X) X(memset) X(memcpy) X(freembuf) X(mem_set_values) X(time) X(time_precise) \
    X(sliderchange) X(slider_automate) X(slider_show) X(strlen) X(strcat) X(strcmp) X(stricmp) X(strncpy) \
    X(strcpy_substr) X(str_getchar) X(str_setchar) X(file_open) X(file_close) X(file_rewind) X(file_avail) \
    X(file_text) X(file_mem) X(file_string) X(export_buffer_to_project) X(get_host_placement) \
    X(get_host_numchan) X(set_host_numchan) X(get_pin_mapping) X(set_pdc) X(printf) X(gfx_getchar)
#define JSFX_DECLARE(name) double jsfx_b_##name(jsfx_inst *S, int nargs, const double *a);
JSFX_BUILTINS(JSFX_DECLARE)
#undef JSFX_DECLARE
double jsfx_sprintf(jsfx_inst *S, double dst, double fmt, int nargs, const double *args);
double jsfx_strcpy(jsfx_inst *S, double dst, double src);
double jsfx_unknown(jsfx_inst *S, const char *name);
const char *jsfx_str_get(jsfx_inst *S, double id, int *len);

#ifdef __cplusplus
}
#endif
#endif
