#!/bin/bash
# build.sh: rebuild the ELFs (VARIANT 2 = cbo.zero, VARIANT 1 = sw control) with a riscv64-unknown-elf toolchain.
cd "$(dirname "$0")"
CC=${CC:-riscv64-unknown-elf-gcc}
$CC -march=rv64gc_zicboz -mabi=lp64 -nostdlib -nostartfiles -T link.ld -DVARIANT=2 lrsc-cbo-zero-2h.S -o lrsc-cbo-zero-2h.elf
$CC -march=rv64gc_zicboz -mabi=lp64 -nostdlib -nostartfiles -T link.ld -DVARIANT=1 lrsc-cbo-zero-2h.S -o lrsc-sw-control-2h.elf
