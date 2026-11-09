#!/bin/bash
# run.sh [path/to/whisper]: run the reproducer ELF(s) on Whisper and print PASS or FAIL for each
# (exit status 0 = all pass). A FAIL lists the failed checks.
W=${1:-whisper}
case $W in */*) W=$(cd "$(dirname "$W")" && pwd)/$(basename "$W");; esac
cd "$(dirname "$0")" || exit 1
status=0
run() {  # run <elf> <whisper config>
  out=$(timeout 300 "$W" --maxinst 100000000:f --config "$2" "$1" 2>&1)
  if echo "$out" | grep -q "Successful stop"; then
    echo "PASS $1"
  else
    echo "FAIL $1"; status=1
    echo "$out" | grep -E "SA-MISMATCH|RVCP: Test Info|Assertion|Error" | sed "s/^/    /"
  fi
}
run pbmt-misaligned-cross-page.elf whisper.json
if [ $status = 0 ]; then echo PASS; else echo FAIL; fi
exit $status
