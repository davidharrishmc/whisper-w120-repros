#!/bin/bash
# run.sh <whisper>: tohost = (n<<1)|1; n=0 pass, n=1 first load wrong, n=2 load after fence wrong, 99 trap
cd "$(dirname "$0")"; W=${1:-whisper}
r() { $W --maxinst 100000 --config $1 $2.elf --logfile $2.log > /dev/null 2>&1
  v=$(grep 'sd       x31' $2.log | tail -1 | awk '{print $8}'); n=$(( 0x${v:-0} >> 1 ))
  if [ -n "$v" ] && [ "$n" = 0 ]; then echo "$2 [$1]: PASS"; else echo "$2 [$1]: FAIL check $n"; fi; }
r base.json sfence_asid_ctrl
r asid7.json sfence_asid_bit7
r base.json sfence_asid_bit20
r base.json sfence_asid_vs_ctrl
r asid7.json sfence_asid_vs_bit7
r base.json sfence_asid_vs_bit20
# Probes: the fence names another ASID (2), so "FAIL check 2" here is the expected result and shows that the
# simulator keeps ASID 1 translations across it (needed for the tests above to mean anything).
r base.json sfence_asid_probe
r base.json sfence_asid_vs_probe
