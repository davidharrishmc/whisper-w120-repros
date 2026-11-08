#!/bin/bash
# build.sh: build step_rv64.elf and step_rv32.elf from step.S (riscv64-unknown-elf-gcc).
cd "$(dirname "$0")"
riscv64-unknown-elf-gcc -march=rv64gch -mabi=lp64 -nostdlib -nostartfiles -T link.ld -o step_rv64.elf step.S
riscv64-unknown-elf-gcc -march=rv32gch -mabi=ilp32 -nostdlib -nostartfiles -T link.ld -o step_rv32.elf step.S
