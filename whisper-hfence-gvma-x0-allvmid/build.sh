#!/bin/bash
# build.sh: build the Whisper ELFs (*.elf), the QEMU variants (*_qemu.elf) and, for Spike, Sail and Imperas, variants without the
# Smrnmi mnstatus write (*_nosmrnmi.elf; those simulators lack Smrnmi). QEMU variants also omit it.
cd "$(dirname "$0")"
G="riscv64-unknown-elf-gcc -march=rv64gc -mabi=lp64 -nostdlib -nostartfiles -static -T link.ld"
for t in gvma_samevmid_ctrl gvma_allvmid_x0 gvma_allvmid_gpa gvma_othervmid_probe; do
  $G $t.S -o $t.elf && $G -DQEMU -DNO_SMRNMI $t.S -o ${t}_qemu.elf && $G -DNO_SMRNMI $t.S -o ${t}_nosmrnmi.elf || exit 1
done
