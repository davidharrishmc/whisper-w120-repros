#!/bin/bash
# build.sh: build trig_rv64.elf and trig_rv32.elf from trig.S (riscv64-unknown-elf-gcc).
cd "$(dirname "$0")"
riscv64-unknown-elf-gcc -march=rv64gch -mabi=lp64 -nostdlib -nostartfiles -T link.ld -o trig_rv64.elf trig.S
riscv64-unknown-elf-gcc -march=rv32gch -mabi=ilp32 -nostdlib -nostartfiles -T link.ld -o trig_rv32.elf trig.S
