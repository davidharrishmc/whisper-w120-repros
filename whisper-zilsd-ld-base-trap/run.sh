#!/bin/bash
# run.sh [whisper]: x31 = 0 pass, else the number of the failing check (see zilsd_ld_base.S)
cd "$(dirname "$0")"; W=${1:-whisper}
r() { $W --maxinst 100000 --config $1 $2.elf --logfile $2.log > /dev/null 2>&1
  v=$(grep 'sw       x5, 0x0(x6)' $2.log | tail -1 | awk '{print $8}'); n=$(( 0x${v:-0} >> 1 ))
  if [ -n "$v" ] && [ "$n" = 0 ]; then echo "$2 [$1]: PASS"; else echo "$2 [$1]: FAIL check $n"; fi; }
r whisper.json zilsd_ld_base
r whisper-zclsd.json zilsd_ld_base_zclsd
