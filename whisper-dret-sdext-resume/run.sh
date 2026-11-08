#!/bin/bash
# run.sh [whisper]: run dret_rv{64,32}.elf (MPRV/MDT/SDT) and pelp_rv{64,32}.elf (ELP and dcsr.pelp); print the
# failed checks (x31 bitmask, plus dcsr.pelp read after the dret with Whisper's interactive peek) and exit status.
cd "$(dirname "$0")"
W=${1:-whisper}
status=0
x31of() {  # x31 from the tohost store in the --log trace
  local x5; x5=$(echo "$1" | grep "slli     x5, x31, 1" | tail -1 | awk '{print $8}')
  echo $((16#${x5:-0} >> 1))
}
for x in 64 32; do
log=$(timeout 60 "$W" --maxinst 20000 --config whisper-rv$x.json --log dret_rv$x.elf 2>&1)
x31=$(x31of "$log")
names=(MPRV MDT SDT vsstatus.SDT); modes=(M S U VS VU)
printf "rv$x dret: x31 = 0x%x\n" $x31
for i in $(seq 1 31); do
  if (( (x31 >> i) & 1 )); then
    if (( i <= 20 )); then s=$(( (i-1)/4 )); f=$(( (i-1)%4 )); echo "  FAIL check $i: dret to ${modes[$s]}: ${names[$f]}"
    else echo "  FAIL check $i"; fi
  fi
done
if (( x31 == 0 )); then echo "  PASS"; else status=1; fi

log=$(timeout 60 "$W" --maxinst 20000 --config whisper-rv$x.json --log pelp_rv$x.elf 2>&1)
x31=$(x31of "$log")
# Debugger view: stop at no_lpad (the dret target, before it executes) and read dcsr.
a=$(riscv64-unknown-elf-nm pelp_rv$x.elf 2>/dev/null | awk '/ no_lpad$/{print $1}'); a=${a:-80000088}
dcsr=$(printf "until 0x%s\npeek c dcsr\nquit\n" "$a" | timeout 60 "$W" --config whisper-rv$x.json --interactive pelp_rv$x.elf 2>/dev/null | tail -1)
if (( (dcsr >> 18) & 1 )); then x31=$(( x31 | (1 << 6) )); fi
printf "rv$x pelp: x31 = 0x%x (dcsr after dret = %s)\n" $x31 "$dcsr"
pnames=([1]="dcsr.pelp not writable in Debug Mode (config)" [2]="no software-check exception at the dret target (ELP not restored)"
        [3]="mcause != 18" [4]="mtval != 2" [5]="mepc != no_lpad" [6]="dcsr.pelp still 1 after dret")
for i in $(seq 1 31); do
  if (( (x31 >> i) & 1 )); then echo "  FAIL check $i: ${pnames[$i]:-unexpected}"; fi
done
if (( x31 == 0 )); then echo "  PASS"; else status=1; fi
done
exit $status
