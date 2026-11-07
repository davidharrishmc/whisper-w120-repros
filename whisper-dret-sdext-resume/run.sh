#!/bin/bash
# run.sh [whisper]: run dret_rv64.elf and dret_rv32.elf; print the failed checks (x31 bitmask) and the exit status.
cd "$(dirname "$0")"
W=${1:-whisper}
status=0
for x in 64 32; do
log=$(timeout 60 "$W" --maxinst 20000 --config whisper-rv$x.json --log dret_rv$x.elf 2>&1)
x5=$(echo "$log" | grep "slli     x5, x31, 1" | tail -1 | awk '{print $8}')
x31=$((16#${x5:-0} >> 1))
names=(MPRV MDT SDT vsstatus.SDT); modes=(M S U VS VU)
printf "rv$x: x31 = 0x%x\n" $x31
for i in $(seq 1 31); do
  if (( (x31 >> i) & 1 )); then
    if (( i <= 20 )); then s=$(( (i-1)/4 )); f=$(( (i-1)%4 )); echo "  FAIL check $i: dret to ${modes[$s]}: ${names[$f]}"
    else echo "  FAIL check $i"; fi
  fi
done
if (( x31 == 0 )); then echo "  PASS"; else status=1; fi
done
exit $status
