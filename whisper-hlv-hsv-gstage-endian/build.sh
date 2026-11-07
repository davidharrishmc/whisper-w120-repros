#!/bin/bash
# build.sh <name>: build <name>_rv{64,32}.elf (HTIF) and <name>_rv{64,32}_qemu.elf (QEMU virt) from <name>.S.
cd "$(dirname "$0")"
for x in 64 32; do
  a=$([ $x = 64 ] && echo lp64 || echo ilp32)
  riscv64-unknown-elf-gcc -march=rv${x}gch -mabi=$a -nostdlib -nostartfiles -T link.ld -o $1_rv$x.elf $1.S
  riscv64-unknown-elf-gcc -DQEMU -march=rv${x}gch -mabi=$a -nostdlib -nostartfiles -T link.ld -o $1_rv${x}_qemu.elf $1.S
done
