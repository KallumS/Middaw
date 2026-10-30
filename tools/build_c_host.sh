#!/bin/sh
# Builds build/jsfx_c_host: tools/jsfx_c_host.c over the compiled devices.
set -e
cd "$(dirname "$0")/.."
mkdir -p build
C=mac/Sources/CJSFX
${CC:-cc} -std=gnu11 -O2 -I$C/include -o build/jsfx_c_host tools/jsfx_c_host.c $C/jsfx_rt.c $C/devices/*.c -lm
