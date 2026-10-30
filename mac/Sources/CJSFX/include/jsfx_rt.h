/* The family's JSFX, compiled to C.
 *
 * tools/jsfx2c.js translates each device's EEL2 into C (the files in
 * devices/, generated, not edited), the same way runtime/jsfx/jsfx.js
 * translates it into JavaScript - same parser, same rules. This is the small
 * runtime that generated code runs on: an instance's variables, its memory,
 * strings, MIDI in and out, saved state, sample files and gmem.
 *
 * This is the host's side; jsfx_internal.h is the generated code's. Nothing
 * here locks; while audio is processed nothing allocates except a string
 * growing past any length it has had before.
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
/* What a host reads and writes besides sliders: memory, gmem (a REAPER
 * script's shared memory), strings (a file name handed to a function). */
double jsfx_mem(jsfx_inst *S, double addr);
double *jsfx_gmem(jsfx_inst *S);
void jsfx_set_string(jsfx_inst *S, double id, const char *text);
const char *jsfx_get_string(jsfx_inst *S, double id);
/* For tests: replace rand() with a fixed sequence. */
void jsfx_seed(jsfx_inst *S, uint32_t seed);

#ifdef __cplusplus
}
#endif
#endif
