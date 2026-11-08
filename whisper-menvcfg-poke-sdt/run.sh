#!/bin/bash
# run.sh [whisper]: for RV64 and RV32, run sdt_rv$x.elf straight through, then again with a snapshot saved
# after 40 instructions (in the M-mode nop sled), then from that snapshot (--loadfrom); print the failed
# checks (x31 bitmask) of the straight and restored runs and the exit status (0 = all pass).
cd "$(dirname "$0")"
W=${1:-whisper}
P=40   # snapshot point: instruction 40 is in the nop sled on RV64 and RV32
status=0
names=([1]="mstatus.SDT lost" [2]="henvcfg.DTE reads 0" [3]="sstatus.SDT not writable/readable"
       [4]="vsstatus.SDT not writable/readable" [7]="unexpected trap")
report() {  # report <label> <log>
  local x5 x31; x5=$(echo "$2" | grep "slli     x5, x31, 1" | tail -1 | awk '{print $8}')
  if [ -z "$x5" ]; then echo "$1: no tohost write"; status=1; return; fi
  x31=$((16#$x5 >> 1))
  printf "%s: x31 = 0x%x\n" "$1" $x31
  for i in $(seq 1 31); do
    if (( (x31 >> i) & 1 )); then echo "  FAIL check $i: ${names[$i]:-unexpected}"; fi
  done
  if (( x31 == 0 )); then echo "  PASS"; else status=1; fi
}
for x in 64 32; do
  report "rv$x straight run" "$(timeout 60 "$W" --maxinst 20000 --config whisper-rv$x.json --log sdt_rv$x.elf 2>&1)"
  rm -rf snap-rv$x
  timeout 60 "$W" --maxinst 20000 --config whisper-rv$x.json --snapshotperiod $P --snapshotdir snap-rv$x/s \
    sdt_rv$x.elf > /dev/null 2>&1
  if [ ! -f snap-rv$x/s0/registers ]; then echo "rv$x: no snapshot saved"; status=1; continue; fi
  echo "rv$x snapshot at instruction $P: $(grep -E '^(pm|pc) ' snap-rv$x/s0/registers | tr '\n' ' ')"
  report "rv$x restored from snapshot" "$(timeout 60 "$W" --maxinst 20000 --config whisper-rv$x.json \
    --loadfrom snap-rv$x/s0 --log sdt_rv$x.elf 2>&1)"
done
exit $status
