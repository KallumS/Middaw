/* The family's JSFX, compiled to C.
 *
 * tools/jsfx2c.js translates each device's EEL2 into C (the files in
 * devices/, generated, not edited), the same way runtime/jsfx/jsfx.js
 * translates it into JavaScript - same parser, same rules. This is the small
 * runtime that generated code runs on: an instance's variables, its memory,
 * strings, MIDI in and out, saved state, sample files and gmem.
 *
 * Nothing here allocates or locks while audio is processed, except a string
 * or a file growing, which the family's devices do in @init and @slider.
 */
#ifndef JSFX_RT_H
#define JSFX_RT_H

#include <stdint.h>
#include <stddef.h>
#include <math.h>

#ifdef __cplusplus
extern "C" {
#endif

#define JSFX_EPS 0.00001
#define JSFX_MAXLOOP 1048576.0
#define JSFX_MEMWORDS (8 * 1024 * 1024)
#define JSFX_GMEMWORDS (8 * 1024 * 1024)
#define JSFX_MIDIOUT 4096

typedef struct jsfx_inst jsfx_inst;
typedef double (*jsfx_section_fn)(jsfx_inst *);
typedef double (*jsfx_call_fn)(jsfx_inst *, const double *);

typedef struct {
    int index;                 /* slider1 is 1 */
    const char *variable;
    double def, min, max, step;
    const char *name;
    int hidden;
    int nnames;                /* an enum slider's choices */
    const char *const *names;
    int shape;                 /* 0 linear, 1 log, 2 sqr */
    double shapeValue;
} jsfx_slider;

typedef struct {
    const char *name;
    int nparams;
    jsfx_call_fn fn;
} jsfx_func;

typedef struct {
    const char *id;
    const char *desc;
    int nvars;
    const char *const *varnames;     /* slot -> name, for the host */
    int nsliders;
    const jsfx_slider *sliders;
    const int *sliderSlot;           /* slider index 0..64 -> slot, -1 if none */
    int nsections[5];                /* init, slider, block, sample, serialize */
    const jsfx_section_fn *sections[5];
    int nstrings;
    const char *const *strings;      /* literals, ids 10000 + i */
    int nnamed;                      /* named strings, ids 90000 + i */
    int nfuncs;
    const jsfx_func *funcs;          /* every function the host may call */
    const char *gmemName;
    int inPins, outPins;
    int s_srate, s_samplesblock, s_tempo, s_play_state, s_play_position, s_beat_position, s_ts_num, s_ts_denom, s_num_ch;
    int s_spl[64];
} jsfx_desc;

typedef struct { int offset; int len; uint8_t data[3]; } jsfx_midi;

typedef struct { int isString; double value; char *string; } jsfx_serial_item;

typedef struct {
    char *name;
    double *values;
    int64_t count;
    int channels;
    double rate;
} jsfx_file;

typedef struct { int file; int64_t pos; } jsfx_handle;   /* file is index + 1, 0 when closed */

typedef struct { int64_t id; char *s; int len; int used; } jsfx_str;

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

/* ------------------------------------------------------------ the host -- */
const jsfx_desc *jsfx_find(const char *id);
int jsfx_count(void);
const jsfx_desc *jsfx_at(int i);

jsfx_inst *jsfx_new(const jsfx_desc *d, double srate);
void jsfx_free(jsfx_inst *S);
void jsfx_init(jsfx_inst *S, double srate);
void jsfx_set_slider(jsfx_inst *S, int index, double value);
double jsfx_get_slider(jsfx_inst *S, int index);
void jsfx_set_time(jsfx_inst *S, double tempo, double playState, double beat, double seconds, double num, double den);
/* One block. in/out are per-channel buffers (NULL for none). Returns the
 * number of MIDI events sent, which jsfx_midi_out() then holds. */
int jsfx_process(jsfx_inst *S, int n, const float *const *in, int nin, float *const *out, int nout,
                 const jsfx_midi *midi, int nmidi);
const jsfx_midi *jsfx_midi_out(jsfx_inst *S);
double jsfx_get_var(jsfx_inst *S, const char *name);
void jsfx_set_var(jsfx_inst *S, const char *name, double value);
/* Call one of the plug-in's own functions by name (a device's buttons). */
int jsfx_call(jsfx_inst *S, const char *name, const double *args, int nargs, double *result);
/* A sound for file_open(name): interleaved samples. Copied. */
void jsfx_add_file(jsfx_inst *S, const char *name, const float *interleaved, int64_t frames, int channels, double rate);
/* @serialize: into items the host keeps, and back. */
int jsfx_serialize(jsfx_inst *S, jsfx_serial_item **items);
void jsfx_deserialize(jsfx_inst *S, const jsfx_serial_item *items, int count);
void jsfx_free_items(jsfx_serial_item *items, int count);
int jsfx_take_slider_change(jsfx_inst *S);
/* JavaScript's String(x), for hosts that print numbers as runtime/jsfx/jsfx.js does. */
int jsfx_js_number(double x, char *out, size_t cap);
/* For tests: the clock time_precise() and time() read (seconds), NULL for the system's. */
extern double (*jsfx_clock)(void);
/* For tests: replace rand() with a fixed sequence. */
void jsfx_seed(jsfx_inst *S, uint32_t seed);

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
