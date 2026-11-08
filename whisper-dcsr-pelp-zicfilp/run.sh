#!/bin/bash
# run.sh [whisper]: run pelp_rv64.elf and pelp_rv32.elf; print the failed checks (x31 bitmask) and the exit
# status (0 = pass).
cd "$(dirname "$0")"
W=${1:-whisper}
status=0
names=([1]="dcsr.pelp = 0 after the trigger halt (ELP not saved)" [2]="dcsr.cause != trigger (2)"
       [3]="mcause != 18" [4]="mtval != 2" [5]="mepc != no_lpad"
       [6]="no software-check exception at no_lpad after the dret (ELP not restored)" [7]="unexpected path"
       [27]="exception in Debug Mode")
for x in 64 32; do
  log=$(timeout 60 "$W" --maxinst 20000 --config whisper-rv$x.json --log pelp_rv$x.elf 2>&1)
  x5=$(echo "$log" | grep "slli     x5, x31, 1" | tail -1 | awk '{print $8}')
  if [ -z "$x5" ]; then echo "rv$x: no tohost write"; status=1; continue; fi
  x31=$((16#$x5 >> 1))
  printf "rv$x: x31 = 0x%x\n" $x31
  for i in $(seq 1 31); do
    if (( (x31 >> i) & 1 )); then echo "  FAIL check $i: ${names[$i]:-unexpected}"; fi
  done
  if (( x31 == 0 )); then echo "  PASS"; else status=1; fi
done
exit $status
