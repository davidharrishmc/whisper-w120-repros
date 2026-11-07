#!/bin/bash
# build.sh: build dret_rv64.elf and dret_rv32.elf from dret.S (riscv64-unknown-elf-gcc).
cd "$(dirname "$0")"
riscv64-unknown-elf-gcc -march=rv64gch -mabi=lp64 -nostdlib -nostartfiles -T link.ld -o dret_rv64.elf dret.S
riscv64-unknown-elf-gcc -march=rv32gch -mabi=ilp32 -nostdlib -nostartfiles -T link.ld -o dret_rv32.elf dret.S
