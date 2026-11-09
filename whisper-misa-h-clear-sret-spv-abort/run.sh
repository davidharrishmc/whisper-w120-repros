#!/bin/bash
# run.sh [path/to/whisper]: run each self-checking ELF with its whisper JSON configuration and print
# PASS or FAIL with the checks that failed. Exit status 0 = all pass.
cd "$(dirname "$0")"
W=${1:-whisper}
ulimit -c 0  # no core file if whisper aborts
status=0
run() {  # run <elf> <config>
  local out
  out=$(timeout 120 "$W" --maxinst 100000000:f --config "$2" "$1" 2>&1)
  if echo "$out" | grep -q "TEST PASSED"; then
    echo "PASS $1"
  else
    status=1
    if echo "$out" | grep -q "TEST FAILED"; then echo "FAIL $1"; else echo "FAIL $1 (no test result; last lines of output:)"; echo "$out" | grep -av "^Warning:\|^timeout:" | tail -2 | sed 's/^/    /'; fi
  fi
  echo "$out" | grep -aE "SA-MISMATCH|RVCP: Test Info" | sed 's/^/  /'
}
run whisper-misa-h-sret-spv-rv64.elf whisper-rv64.json
run whisper-misa-h-sret-spv-rv32.elf whisper-rv32.json
exit $status
