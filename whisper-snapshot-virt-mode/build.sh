#!/bin/bash
# build.sh: build snapvirt_rv64.elf and snapvirt_rv32.elf from snapvirt.S (riscv64-unknown-elf-gcc).
cd "$(dirname "$0")"
riscv64-unknown-elf-gcc -march=rv64gch -mabi=lp64 -nostdlib -nostartfiles -T link.ld -o snapvirt_rv64.elf snapvirt.S
riscv64-unknown-elf-gcc -march=rv32gch -mabi=ilp32 -nostdlib -nostartfiles -T link.ld -o snapvirt_rv32.elf snapvirt.S
