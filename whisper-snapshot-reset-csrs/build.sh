#!/bin/bash
# build.sh: build mdt_rv64.elf and mdt_rv32.elf from mdt.S (riscv64-unknown-elf-gcc).
cd "$(dirname "$0")"
riscv64-unknown-elf-gcc -march=rv64gch -mabi=lp64 -nostdlib -nostartfiles -T link.ld -o mdt_rv64.elf mdt.S
riscv64-unknown-elf-gcc -march=rv32gch -mabi=ilp32 -nostdlib -nostartfiles -T link.ld -o mdt_rv32.elf mdt.S
