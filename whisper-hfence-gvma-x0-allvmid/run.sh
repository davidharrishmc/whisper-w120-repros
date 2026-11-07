#!/bin/bash
# run.sh <whisper>: tohost = (n<<1)|1; n=0 pass, n=1 first load wrong, n=2 load after fence wrong, 99 trap
cd "$(dirname "$0")"; W=${1:-whisper}
r() { $W --maxinst 100000 --config $1 $2.elf --logfile $2.log > /dev/null 2>&1
  v=$(grep 'sd       x31' $2.log | tail -1 | awk '{print $8}'); n=$(( 0x${v:-0} >> 1 ))
  if [ -n "$v" ] && [ "$n" = 0 ]; then echo "$2 [$1]: PASS"; else echo "$2 [$1]: FAIL check $n"; fi; }
r base.json gvma_samevmid_ctrl
r base.json gvma_allvmid_x0
r base.json gvma_allvmid_gpa
# Probe: the fence names VMID 2 only, so "FAIL check 2" here is the expected result and shows that the
# simulator keeps VMID 1 G-stage translations across it (needed for the tests above to mean anything).
r base.json gvma_othervmid_probe
