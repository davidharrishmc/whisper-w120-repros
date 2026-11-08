#!/bin/bash
# build.sh: build dret_rv{64,32}.elf from dret.S and pelp_rv{64,32}.elf from pelp.S (riscv64-unknown-elf-gcc).
cd "$(dirname "$0")"
riscv64-unknown-elf-gcc -march=rv64gch -mabi=lp64 -nostdlib -nostartfiles -T link.ld -o dret_rv64.elf dret.S
riscv64-unknown-elf-gcc -march=rv32gch -mabi=ilp32 -nostdlib -nostartfiles -T link.ld -o dret_rv32.elf dret.S
riscv64-unknown-elf-gcc -march=rv64gch_zicfilp -mabi=lp64 -nostdlib -nostartfiles -T link.ld -o pelp_rv64.elf pelp.S
riscv64-unknown-elf-gcc -march=rv32gch_zicfilp -mabi=ilp32 -nostdlib -nostartfiles -T link.ld -o pelp_rv32.elf pelp.S
