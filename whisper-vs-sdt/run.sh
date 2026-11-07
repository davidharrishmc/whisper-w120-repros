#!/bin/bash
# run.sh [whisper]: run whisper_vs_sdt on Whisper (riscv-arch-test whisper-rv64-max config) and print x31,
# the bitmask of failed checks (0 = pass).
cd "$(dirname "$0")"
W=${1:-whisper}
x5=$(timeout 300 "$W" --config whisper.json --log whisper_vs_sdt.elf 2>&1 | grep "slli     x5, x31, 1" | awk '{print $8}')
x31=$((16#$x5 >> 1))
printf "x31 = 0x%x\n" $x31
if [ $x31 -eq 0 ]; then echo "whisper_vs_sdt: PASS"; else echo "whisper_vs_sdt: FAIL"; fi
