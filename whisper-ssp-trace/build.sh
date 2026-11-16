#!/bin/bash
# build.sh: rebuild ssp.elf with a riscv64-unknown-elf GCC toolchain.
cd "$(dirname "$0")"
riscv64-unknown-elf-gcc -march=rv64ima_zicsr_zimop_zicfiss -mabi=lp64 -nostdlib -nostartfiles -T link.ld -o ssp.elf ssp.S
