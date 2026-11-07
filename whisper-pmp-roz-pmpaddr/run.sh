#!/bin/bash
# run.sh [whisper]: run pmp_roz (prebuilt w_rv64.elf, w_rv32.elf) on Whisper with pmpaddr8 read-only zero
# (whisper-rv*.json) and with every pmpaddr read-only zero (whisper-rv*-roall.json); print x31, the bitmask of
# failed checks (0 = pass).
cd "$(dirname "$0")"
W=${1:-whisper}
for x in 64 32; do
  for c in "" -roall; do
    x5=$(timeout 60 "$W" --maxinst 100000 --config whisper-rv$x$c.json --log w_rv$x.elf 2>&1 | grep "slli     x5, x31, 1" | awk '{print $8}')
    x31=$((16#${x5:-1ff} >> 1))
    printf "%-22s x31 = 0x%x " whisper-rv$x$c.json $x31
    if [ $x31 -eq 0 ]; then echo "PASS"; else echo "FAIL"; fi
  done
done
