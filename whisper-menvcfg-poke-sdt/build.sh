#!/bin/bash
# build.sh: build sdt_rv64.elf and sdt_rv32.elf from sdt.S (riscv64-unknown-elf-gcc).
cd "$(dirname "$0")"
riscv64-unknown-elf-gcc -march=rv64gch -mabi=lp64 -nostdlib -nostartfiles -T link.ld -o sdt_rv64.elf sdt.S
riscv64-unknown-elf-gcc -march=rv32gch -mabi=ilp32 -nostdlib -nostartfiles -T link.ld -o sdt_rv32.elf sdt.S
