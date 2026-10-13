#!/bin/bash
# Usage: ./run.sh [whisper] [spike] [sail_riscv_sim]
# Runs stateen-se-rv64.elf and stateen-se-rv32.elf on each simulator and prints PASS or FAIL.
# The test writes 1 to tohost on success and (n << 1) | 1 when check n fails.
cd "$(dirname "$0")"
W=${1:-whisper}; S=${2:-spike}; A=${3:-sail_riscv_sim}
for x in 64 32; do
  e=stateen-se-rv$x.elf
  r=$(timeout 120 $W --maxinst 100000 --config whisper-rv$x.json $e 2>&1)
  echo "$r" | grep -q "Successful stop" && r=PASS || r=FAIL
  echo "rv$x whisper: $r"
  timeout 120 $S $(cat spike-args-rv$x.txt) $e > /dev/null 2>&1 && r=PASS || r="FAIL (exit $?)"
  echo "rv$x spike:   $r"
  r=$(timeout 120 $A --config sail-rv$x.json $e 2>&1 | grep -E "SUCCESS|FAILURE|Assertion" | head -1)
  case "$r" in SUCCESS*) r=PASS;; *) r="FAIL ($r)";; esac
  echo "rv$x sail:    $r"
done
