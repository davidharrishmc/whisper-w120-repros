#!/bin/bash
# run.sh [whisper]: run hlv_rv64.elf and hlv_rv32.elf; print the failed checks (x31 bitmask).
cd "$(dirname "$0")"
W=${1:-whisper}
status=0
for x in 64 32; do
  log=$(timeout 60 "$W" --maxinst 20000 --config whisper-rv$x.json --log hlv_rv$x.elf 2>&1)
  x5=$(echo "$log" | grep "slli     x5, x31, 1" | tail -1 | awk '{print $8}')
  if [ -z "$x5" ]; then echo "rv$x: did not reach the exit: $(echo "$log" | grep -E "Error|stop" | head -1)"; status=1; continue; fi
  x31=$((16#$x5 >> 1))
  printf "rv$x: x31 = 0x%x :" $x31
  for i in $(seq 1 31); do (( (x31 >> i) & 1 )) && printf " %d" $i; done
  if (( x31 == 0 )); then echo " PASS"; else echo " (failed checks)"; status=1; fi
done
exit $status
