#!/bin/bash
# build.sh path/to/whisper-source: build trig.elf (riscv64-unknown-elf-gcc) and the tracer pctrace.so
# (with the defines and include paths of Whisper's GNUmakefile).
cd "$(dirname "$0")"
W=${1:?usage: build.sh path/to/whisper-source}
riscv64-unknown-elf-gcc -march=rv64i_zicsr -mabi=lp64 -nostdlib -nostartfiles -T link.ld -o trig.elf trig.S
g++ -std=c++20 -O2 -mfma -fPIC -shared -DSOFT_FLOAT -DTHREAD_LOCAL=__thread -DMEM_CALLBACKS \
  -I"$W" -isystem "$W/third_party" -I"$W/third_party/softfloat/source/include" -o pctrace.so pctrace.cpp
