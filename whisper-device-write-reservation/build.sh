#!/bin/bash
# build.sh: rebuild the ELF with a riscv64-unknown-elf toolchain.
cd "$(dirname "$0")"
${CC:-riscv64-unknown-elf-gcc} -march=rv64gc -mabi=lp64 -nostdlib -nostartfiles -T link.ld lrsc-iommu-write.S -o lrsc-iommu-write.elf
