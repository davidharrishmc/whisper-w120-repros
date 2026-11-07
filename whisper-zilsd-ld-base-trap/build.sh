#!/bin/bash
# build.sh: build the Whisper ELFs (zilsd_ld_base.elf; zilsd_ld_base_zclsd.elf adds the Zclsd c.ld checks), the QEMU
# variants (*_qemu.elf) and, for Spike and Imperas, variants without the Smrnmi mnstatus write (*_nosmrnmi.elf;
# those simulators lack Smrnmi). The QEMU variants also omit it.
cd "$(dirname "$0")"
G="riscv64-unknown-elf-gcc -march=rv32ima_zicsr -mabi=ilp32 -nostdlib -nostartfiles -static -T link.ld"
for z in "" -DZCLSD; do
  s=${z:+_zclsd}
  $G $z zilsd_ld_base.S -o zilsd_ld_base$s.elf || exit 1
  $G $z -DQEMU -DNO_SMRNMI zilsd_ld_base.S -o zilsd_ld_base${s}_qemu.elf || exit 1
  $G $z -DNO_SMRNMI zilsd_ld_base.S -o zilsd_ld_base${s}_nosmrnmi.elf || exit 1
done
