#!/bin/bash
# build.sh: rebuild the ELFs with a riscv64-unknown-elf toolchain. VARIANT 4 = A-bit update by a load,
# 5 = D-bit update by a store, 1 = control (an ordinary sd sets A). WHISPER sets mnstatus.NMIE (Smrnmi).
cd "$(dirname "$0")"
CC=${CC:-riscv64-unknown-elf-gcc}
for v in 4:a-bit 5:d-bit 1:sd-control; do
  $CC -march=rv64gc -mabi=lp64 -nostdlib -nostartfiles -T link.ld -DWHISPER -DVARIANT=${v%%:*} lrsc-ad-update-2h.S \
      -o lrsc-ad-update-2h-${v#*:}.elf
done
