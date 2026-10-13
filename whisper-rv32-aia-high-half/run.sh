#!/bin/bash
# Usage: ./run.sh [whisper] [spike] [sail_riscv_sim]
# Runs aia-high-rv32.elf on each simulator and prints PASS or FAIL. The test runs every
# check and writes 1 to tohost on success, or (failmask << 1) | 1 otherwise: bit 0 sieh,
# bit 1 siph, bit 2 vsieh, bit 3 vsiph, bit 4 an unexpected trap.
cd "$(dirname "$0")"
W=${1:-whisper}; S=${2:-spike}; A=${3:-sail_riscv_sim}
e=aia-high-rv32.elf
r=$(timeout 120 $W --maxinst 100000 --config whisper-rv32.json --log $e 2>&1)
if echo "$r" | grep -q "Successful stop"; then
  echo "rv32 whisper: PASS"
else
  v=$(echo "$r" | grep -E ' sw +x3, 0x0\(x6\)' | tail -1 | awk '{print $8}')
  if [ -n "$v" ]; then echo "rv32 whisper: FAIL (failmask $(( (16#$v) >> 1 )))"; else echo "rv32 whisper: FAIL"; fi
fi
timeout 120 $S $(cat spike-args-rv32.txt) $e > /dev/null 2>&1; rc=$?
if [ $rc -eq 0 ]; then echo "rv32 spike:   PASS"; else echo "rv32 spike:   FAIL (failmask $rc)"; fi
r=$(timeout 120 $A --config sail-rv32.json $e 2>&1 | grep -E "SUCCESS|FAILURE|Assertion" | head -1)
case "$r" in SUCCESS*) r=PASS;; *) r="FAIL ($r)";; esac
echo "rv32 sail:    $r (Sail 0.15 has no Smaia/Ssaia)"
