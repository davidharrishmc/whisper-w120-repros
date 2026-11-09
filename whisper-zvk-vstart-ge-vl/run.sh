#!/bin/bash
# run.sh path/to/whisper: run the self-checking test on Whisper and print PASS or FAIL for each ELF
# (exit status 0 = all pass). On a failure it also prints the test's RVCP failure report.
cd "$(dirname "$0")"
W=${1:-whisper}
status=0
run() {
  out=$(timeout 300 "$W" --maxinst 100000000:f --config "$2" "$1" 2>&1); rc=$?
  if [ $rc -eq 0 ] && echo "$out" | grep -q "TEST PASSED"; then
    echo "$1: PASS"
  else
    status=1
    if [ $rc -gt 128 ]; then echo "$1: FAIL (whisper died with signal $((rc - 128)))"; else echo "$1: FAIL (exit $rc)"; fi
    echo "$out" | grep -E "Assertion|RVCP: (Test Info|Bad Value)" | sed 's/^/    /'
  fi
}
run zvk-vstart-ge-vl.elf whisper.json
exit $status
