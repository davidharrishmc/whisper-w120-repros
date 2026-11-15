#!/bin/bash
# build.sh: rebuild the ELF(s) with a riscv64-unknown-elf GCC toolchain.
cd "$(dirname "$0")"
for s in *.S; do
  riscv64-unknown-elf-gcc -march=rv64i_zicsr -mabi=lp64 -nostdlib -nostartfiles -T link.ld -o "${s%.S}.elf" "$s"
done
