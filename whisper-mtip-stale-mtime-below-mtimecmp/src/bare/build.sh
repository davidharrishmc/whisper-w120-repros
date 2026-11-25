#!/bin/bash
# build.sh: rebuild the bare-metal ELFs with a riscv64-unknown-elf GCC toolchain (output two directories up, next to run.sh).
cd "$(dirname "$0")"
for s in mtime-write mtime-wrap; do
  riscv64-unknown-elf-gcc -march=rv64i_zicsr -mabi=lp64 -nostdlib -nostartfiles -T link.ld -o ../../$s.bare-rv64.elf $s.S
  riscv64-unknown-elf-objdump -d ../../$s.bare-rv64.elf > ../../$s.bare-rv64.objdump
done
