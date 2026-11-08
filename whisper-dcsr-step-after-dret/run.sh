#!/bin/bash
# run.sh [whisper]: run step_rv64.elf and step_rv32.elf; print the failed checks (x31 bitmask) and the exit
# status (0 = pass).
cd "$(dirname "$0")"
W=${1:-whisper}
status=0
names=([1]="halt 1: dpc != step_b (the dret was counted as the stepped instruction)" [2]="halt 2: dpc != step_c"
       [3]="halt 3: dpc != mhandler (ecall trap)" [4]="dcsr.cause != 4 (step) at some halt"
       [5]="halt 3: mcause != 11 or mepc != step_c" [6]="a0 != 2 (an addi did not execute exactly once)"
       [7]="more than 3 step halts" [8]="mhandler reached after a number of halts other than 3"
       [27]="exception in Debug Mode")
for x in 64 32; do
  log=$(timeout 60 "$W" --maxinst 20000 --config whisper-rv$x.json --log step_rv$x.elf 2>&1)
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
