#!/bin/bash
# run.sh [path/to/whisper]: run both reproducer ELFs on Whisper; print PASS or FAIL and the failed checks.
# Exit status 0 = both pass.
W=${1:-whisper}
case $W in */*) W=$(cd "$(dirname "$W")" && pwd)/$(basename "$W");; esac
cd "$(dirname "$0")"
status=0
run() {   # run <elf> <check names: bit 0, 1, 2, ...>
  local elf=$1; shift
  local names=("$@") out bad i
  out=$(timeout 120 "$W" --maxinst 100000000:f --config whisper.json "$elf" 2>&1)
  if echo "$out" | grep -q 'TEST PASSED'; then echo "$elf: PASS"; return; fi
  status=1
  bad=$(echo "$out" | grep -o 'Bad Value: *0x[0-9a-fA-F]*' | awk '{print $3}')
  if [ -z "$bad" ]; then echo "$elf: FAIL (no result)"; echo "$out" | tail -5; return; fi
  echo "$elf: FAIL (failed-check bitmask $bad)"
  for i in "${!names[@]}"; do (( (bad >> i) & 1 )) && echo "  bit $i: ${names[$i]}"; done
}
for x in amoadd.w lr.w sc.w; do
  h+=("$x: not one trap, or an unexpected cause" "$x: guest-page fault, stval is not 0 or 0x100000000"
      "$x: htval is not 0 or GPA(stval) >> 2" "$x: htinst is not 0 or the transformed instruction with Addr. Offset stval - 0xfffffffe")
  s+=("$x: not one trap, or an unexpected cause" "$x: page fault, stval is not 0 or 0x100000000" "" "")
done
run whisper-amo-straddle-htval.elf "${h[@]}"
run whisper-amo-straddle-stval-s.elf "${s[@]}"
if [ $status = 0 ]; then echo PASS; else echo FAIL; fi
exit $status
