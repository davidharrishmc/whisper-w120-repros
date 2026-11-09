#!/bin/bash
# run.sh [path/to/whisper]: run the reproducer ELF(s) on Whisper. Each is a self-checking riscv-arch-test
# program: it prints "TEST PASSED" or "TEST FAILED" (with the failed check). Prints PASS/FAIL per ELF and
# overall; exit status 0 = all passed.
cd "$(dirname "$0")"
W=${1:-whisper}
status=0
run() {   # run <elf> <whisper.json>
  out=$(timeout 120 "$W" --maxinst 100000000:f --config "$2" "$1" 2>&1)
  if echo "$out" | grep -q "TEST PASSED"; then
    echo "PASS  $1"
  else
    status=1
    echo "FAIL  $1"
    echo "$out" | grep -E "SA-MISMATCH|RVCP: Test Info|RVCP: Bad Value|Assertion" | sed 's/^/      /'
  fi
}
run whisper-ss-misaligned-superpage.elf whisper.json
run whisper-ss-misaligned-superpage-mprv.elf whisper.json
run whisper-ss-misaligned-superpage-vs.elf whisper.json
if [ $status = 0 ]; then echo PASS; else echo FAIL; fi
exit $status
