#!/bin/bash
# build.sh: build the Whisper ELFs (*.elf), the QEMU variants (*_qemu.elf) and, for Spike, Sail and Imperas, variants without the
# Smrnmi mnstatus write (*_nosmrnmi.elf; those simulators lack Smrnmi). QEMU variants also omit it.
cd "$(dirname "$0")"
G="riscv64-unknown-elf-gcc -march=rv64gc -mabi=lp64 -nostdlib -nostartfiles -static -T link.ld"
for q in "" "-DQEMU -DNO_SMRNMI" -DNO_SMRNMI; do
  s=; [ "$q" = "-DQEMU -DNO_SMRNMI" ] && s=_qemu; [ "$q" = -DNO_SMRNMI ] && s=_nosmrnmi
  for t in sfence_asid_ctrl sfence_asid_bit7 sfence_asid_bit20; do $G $q $t.S -o $t$s.elf || exit 1; done
  $G $q -DRS2=1 sfence_asid_vs.S -o sfence_asid_vs_ctrl$s.elf || exit 1
  $G $q "-DRS2=(1|(1<<7))" sfence_asid_vs.S -o sfence_asid_vs_bit7$s.elf || exit 1
  $G $q "-DRS2=(1|(1<<20))" sfence_asid_vs.S -o sfence_asid_vs_bit20$s.elf || exit 1
  $G $q -DRS2=2 sfence_asid_vs.S -o sfence_asid_vs_probe$s.elf || exit 1
  $G $q -DPROBE sfence_asid_ctrl.S -o sfence_asid_probe$s.elf || exit 1
done
