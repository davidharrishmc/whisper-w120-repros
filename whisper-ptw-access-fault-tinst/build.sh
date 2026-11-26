#!/bin/bash
# build.sh: regenerate tinst-ptw.S and rebuild tinst-ptw.elf for Whisper.
cd "$(dirname "$0")" || exit 1
python3 gen.py
riscv64-unknown-elf-gcc -march=rv64gc_h_zicsr_zifencei -mabi=lp64d -nostdlib -nostartfiles -static \
  -T link.ld -DSMRNMI -I include -o tinst-ptw.elf tinst-ptw.S
