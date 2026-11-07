#!/bin/bash
# run.sh [whisper]: run whisper_ctr_sret (prebuilt w_rv64.elf, w_rv32.elf) on Whisper and print x31,
# the bitmask of failed checks (0 = pass).
cd "$(dirname "$0")"
W=${1:-whisper}
for x in 64 32; do
  x5=$(timeout 300 "$W" --config whisper-rv$x.json --log w_rv$x.elf 2>&1 | grep "slli     x5, x31, 1" | awk '{print $8}')
  x31=$((16#$x5 >> 1))
  printf "rv%s: x31 = 0x%x " $x $x31
  if [ $x31 -eq 0 ]; then echo "PASS"; else echo "FAIL"; fi
done
