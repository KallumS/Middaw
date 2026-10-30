/* tools/jsfx_host.js for the compiled devices: the same commands, the same
 * answers, run against mac/Sources/CJSFX instead of runtime/jsfx/jsfx.js, so
 * the family's engine checks hold the C to exactly what they hold the JS to.
 *
 *   tools/build_c_host.sh && build/jsfx_c_host "family/devices/Midi Evolver.jsfx" < commands
 */
#include "jsfx_internal.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

#define BS 256
#define SR 48000.0

static const jsfx_desc *desc;
static jsfx_inst *fx;
static jsfx_midi pending[1024];
static int npending;
static long long sent[65536][4];
static int nsent;
static long long clock_ = 0;
static double play = 0, beat = 0, bpm = 120, num = 4, den = 4;
static int frames = 0;
static float in0[BS], in1[BS], out0[BS], out1[BS];
static double period = 0, amp = 0;
static int seeded = 0; static uint32_t seedv = 0;

static void block(void) {
    jsfx_set_time(fx, bpm, play, beat, beat * 60 / bpm, num, den);
    for (int i = 0; i < BS; i++) {
        float x = period > 0 ? (((long long)floor((double)(clock_ + i) / period) % 2) ? (float)-amp : (float)amp) : 0.0f;
        in0[i] = x; in1[i] = -x;
    }
    const float *in[2] = {in0, in1};
    float *out[2] = {out0, out1};
    int n = jsfx_process(fx, BS, in, 2, out, 2, pending, npending);
    npending = 0;
    const jsfx_midi *m = jsfx_midi_out(fx);
    for (int i = 0; i < n && nsent < 65536; i++) {
        sent[nsent][0] = clock_ + m[i].offset;
        sent[nsent][1] = m[i].data[0];
        sent[nsent][2] = m[i].len > 1 ? m[i].data[1] : 0;
        sent[nsent][3] = m[i].len > 2 ? m[i].data[2] : 0;
        nsent++;
    }
    clock_ += BS;
    if (play == 1 || play == 5) beat += BS / SR * bpm / 60;
}

static double fixed_clock(void) { return 1000.0 + (double)clock_ / SR; }

static void make(int keep, uint32_t rng) {
    fx = jsfx_new(desc, SR);
    if (keep) jsfx_seed(fx, rng);          /* rand() goes on where it was, as one Math.random does */
    else if (seeded) jsfx_seed(fx, seedv);
    jsfx_init(fx, SR);
}

static void print_num(double x) {
    char t[64], s[64];
    snprintf(t, sizeof t, "%.9e", x);           /* toPrecision(10) */
    jsfx_js_number(isfinite(x) ? strtod(t, NULL) : x, s, sizeof s);
    fputs(s, stdout);
}

static void push(int b1, int b2, int b3) {
    if (npending >= 1024) return;
    jsfx_midi *m = &pending[npending++];
    m->offset = 0; m->len = 3;
    m->data[0] = (uint8_t)b1; m->data[1] = (uint8_t)b2; m->data[2] = (uint8_t)b3;
}

int main(int argc, char **argv) {
    if (argc < 2) { fprintf(stderr, "usage: jsfx_c_host fx.jsfx < commands\n"); return 1; }
    /* the device by its file name, as tools/jsfx2c.js names it */
    const char *base = strrchr(argv[1], '/'); base = base ? base + 1 : argv[1];
    char id[256]; int k = 0;
    for (const char *p = base; *p && *p != '.' && k < 255; p++) id[k++] = *p;
    id[k] = 0;
    static const char *const map[][2] = {
        {"AutoCC", "autocc"}, {"Instrument-Creator", "instrument_creator"}, {"MIDI_Production_Center", "midi_production_center"},
        {"Midi Evolver", "midi_evolver"}, {"Reverberator", "reverberator"}, {"TransientShuffler", "transient_shuffler"}};
    for (size_t i = 0; i < sizeof map / sizeof map[0]; i++) if (strcmp(id, map[i][0]) == 0) desc = jsfx_find(map[i][1]);
    if (!desc) { fprintf(stderr, "no compiled device for %s\n", argv[1]); return 1; }
    setvbuf(stdout, NULL, _IOLBF, 0);
    if (getenv("JSFX_SEED")) { seeded = 1; seedv = (uint32_t)strtoul(getenv("JSFX_SEED"), NULL, 10); }
    if (getenv("JSFX_CLOCK") && !strcmp(getenv("JSFX_CLOCK"), "samples")) jsfx_clock = fixed_clock;
    make(0, 0);
    for (int b = 0; b < 4; b++) block();

    char line[4096];
    while (fgets(line, sizeof line, stdin)) {
        char *a[64]; int na = 0;
        for (char *t = strtok(line, " \t\r\n"); t && na < 64; t = strtok(NULL, " \t\r\n")) a[na++] = t;
        if (!na || a[0][0] == '#') continue;
#define N(i, d) (na > (i) ? atof(a[i]) : (d))
        const char *cmd = a[0];
        if (!strcmp(cmd, "slider")) jsfx_set_slider(fx, (int)N(1, 0), N(2, 0));
        else if (!strcmp(cmd, "setvar")) jsfx_set_var(fx, a[1], N(2, 0));
        else if (!strcmp(cmd, "note")) push(0x90 | (((int)N(3, 1) - 1) & 15), (int)N(1, 0), (int)N(2, 0));
        else if (!strcmp(cmd, "noteoff")) push(0x80 | (((int)N(2, 1) - 1) & 15), (int)N(1, 0), 0);
        else if (!strcmp(cmd, "cc")) push(0xB0 | (((int)N(3, 1) - 1) & 15), (int)N(1, 0), (int)N(2, 0));
        else if (!strcmp(cmd, "transport")) { play = N(1, 0); beat = N(2, 0); }
        else if (!strcmp(cmd, "tempo")) { bpm = N(1, 0); num = N(2, 0); den = N(3, 0); }
        else if (!strcmp(cmd, "block")) { int n = (int)N(1, 0); for (int i = 0; i < n; i++) block(); }
        else if (!strcmp(cmd, "midi")) {
            for (int i = 0; i < nsent; i++) printf("MIDI %lld %lld %lld %lld\n", sent[i][0], sent[i][1], sent[i][2], sent[i][3]);
            nsent = 0; puts("ENDMIDI");
        }
        else if (!strcmp(cmd, "frame")) { block(); frames++; printf("FRAME %d\n", frames); }
        else if (!strcmp(cmd, "var")) {
            fputs("VAR", stdout);
            for (int i = 1; i < na; i++) { printf(" %s=", a[i]); print_num(jsfx_get_var(fx, a[i])); }
            putchar('\n');
        }
        else if (!strcmp(cmd, "mem")) {
            fputs("MEM", stdout);
            int n = (int)N(2, 0);
            for (int i = 0; i < n; i++) { putchar(' '); print_num(jsfx_rd(fx, N(1, 0) + i)); }
            putchar('\n');
        }
        else if (!strcmp(cmd, "seed")) { seeded = 1; seedv = (uint32_t)N(1, 0); jsfx_seed(fx, seedv); }
        else if (!strcmp(cmd, "input")) {
            if (na > 1 && !strcmp(a[1], "square")) { period = N(2, 0); amp = N(3, 0); } else { period = 0; amp = 0; }
        }
        else if (!strcmp(cmd, "audio")) {
            fputs("AUDIO", stdout);
            for (int i = 0; i < BS; i++) { putchar(' '); print_num(out0[i]); }
            for (int i = 0; i < BS; i++) { putchar(' '); print_num(out1[i]); }
            putchar('\n');
        }
        else if (!strcmp(cmd, "vars")) {
            /* sorted by name, as the JS host prints them */
            int n = desc->nvars;
            int *ix = (int *)malloc(sizeof(int) * (size_t)n);
            for (int i = 0; i < n; i++) ix[i] = i;
            for (int i = 1; i < n; i++) { int x = ix[i], j = i - 1; while (j >= 0 && strcmp(desc->varnames[ix[j]], desc->varnames[x]) > 0) { ix[j + 1] = ix[j]; j--; } ix[j + 1] = x; }
            fputs("VARS", stdout);
            for (int i = 0; i < n; i++) { printf(" %s=", desc->varnames[ix[i]]); print_num(fx->v[ix[i]]); }
            putchar('\n');
            free(ix);
        }
        else if (!strcmp(cmd, "menutext")) puts("MENU ");
        else if (!strcmp(cmd, "shot")) puts("SHOT 0 0");
        else if (!strcmp(cmd, "log")) puts("ENDLOG");
        else if (!strcmp(cmd, "sync")) puts("SYNC");
        else if (!strcmp(cmd, "reload")) {
            double keep[128]; int ns = desc->nsliders < 128 ? desc->nsliders : 128;
            for (int i = 0; i < ns; i++) keep[i] = jsfx_get_slider(fx, desc->sliders[i].index);
            jsfx_serial_item *items; int count = jsfx_serialize(fx, &items);
            uint32_t rng = fx->rng;
            jsfx_free(fx);
            make(1, rng);
            for (int i = 0; i < ns; i++) jsfx_set_slider(fx, desc->sliders[i].index, keep[i]);
            jsfx_deserialize(fx, items, count);
            jsfx_free_items(items, count);
            for (int b = 0; b < 4; b++) block();
        }
    }
    jsfx_free(fx);
    return 0;
}
