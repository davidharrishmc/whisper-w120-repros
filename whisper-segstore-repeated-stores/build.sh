#!/bin/bash
# build.sh: rebuild segstore_rv64.elf and segstore_rv32.elf (riscv64-unknown-elf-gcc).
cd "$(dirname "$0")"
riscv64-unknown-elf-gcc -march=rv64gcv -mabi=lp64d -nostdlib -nostartfiles -T link.ld segstore.S -o segstore_rv64.elf
riscv64-unknown-elf-gcc -march=rv32gcv -mabi=ilp32d -nostdlib -nostartfiles -T link.ld segstore.S -o segstore_rv32.elf
