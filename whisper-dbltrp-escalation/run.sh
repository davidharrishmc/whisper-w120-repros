#!/bin/bash
# run.sh [whisper]: run dbltrp_entry (prebuilt w_rv64.elf, w_rv32.elf) on Whisper and print x31, the bitmask of
# failed checks (0 = pass).
cd "$(dirname "$0")"
W=${1:-whisper}
for x in 64 32; do
  x5=$(timeout 300 "$W" --maxinst 100000 --config whisper-rv$x.json --log w_rv$x.elf 2>&1 | grep "slli     x5, x31, 1" | tail -1 | awk '{print $8}')
  if [ -z "$x5" ]; then echo "rv$x: FAIL (did not reach the end)"; continue; fi
  x31=$((16#$x5 >> 1))
  printf "rv%s: x31 = 0x%x " $x $x31
  if [ $x31 -eq 0 ]; then echo "PASS"; else printf "FAIL (checks"; for i in $(seq 1 15); do (( (x31 >> i) & 1 )) && printf " %d" $i; done; echo ")"; fi
done
