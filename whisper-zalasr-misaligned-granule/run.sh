#!/bin/bash
# run.sh [path/to/whisper]: run the reproducer ELF on Whisper; print PASS or FAIL and the failed checks.
# whisper.json is the riscv-arch-test whisper-rv64-max configuration with zalasr added to the ISA string.
# Exit status 0 = pass.
W=${1:-whisper}
case $W in */*) W=$(cd "$(dirname "$W")" && pwd)/$(basename "$W");; esac
cd "$(dirname "$0")"
names=("lw.aq at offset 1 traps" "lw.aq at offset 1 returns a wrong value"
       "lh.aq at offset 1 traps" "lh.aq at offset 1 returns a wrong value"
       "ld.aq at offset 1 traps" "ld.aq at offset 1 returns a wrong value"
       "sw.rl at offset 5 traps" "sw.rl at offset 5 stores a wrong value"
       "sh.rl at offset 7 traps" "sh.rl at offset 7 stores a wrong value"
       "sd.rl at offset 3 traps" "sd.rl at offset 3 stores a wrong value"
       "ld.aq at offset 9 (crosses the granule) does not raise a load misaligned or access fault"
       "sd.rl at offset 12 (crosses the granule) does not raise a store misaligned or access fault")
elf=whisper-zalasr-misaligned-granule.elf
out=$(timeout 120 "$W" --maxinst 100000000:f --config whisper.json $elf 2>&1)
if echo "$out" | grep -q 'TEST PASSED'; then echo "$elf: PASS"; echo PASS; exit 0; fi
bad=$(echo "$out" | grep -o 'Bad Value: *0x[0-9a-fA-F]*' | awk '{print $3}')
if [ -z "$bad" ]; then echo "$elf: FAIL (no result)"; echo "$out" | tail -5; echo FAIL; exit 1; fi
echo "$elf: FAIL (failed-check bitmask $bad)"
for i in "${!names[@]}"; do (( (bad >> i) & 1 )) && echo "  bit $i: ${names[$i]}"; done
echo FAIL
exit 1
