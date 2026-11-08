#!/bin/bash
# build.sh: build pelp_rv64.elf and pelp_rv32.elf from pelp.S (riscv64-unknown-elf-gcc with Zicfilp).
cd "$(dirname "$0")"
riscv64-unknown-elf-gcc -march=rv64gch_zicfilp -mabi=lp64 -nostdlib -nostartfiles -T link.ld -o pelp_rv64.elf pelp.S
riscv64-unknown-elf-gcc -march=rv32gch_zicfilp -mabi=ilp32 -nostdlib -nostartfiles -T link.ld -o pelp_rv32.elf pelp.S
