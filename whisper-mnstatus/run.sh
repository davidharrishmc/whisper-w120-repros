#!/bin/bash
# Usage: ./run.sh [whisper] [spike] [sail_riscv_sim]
# mnstatus.elf runs every check and writes 1 to tohost when all pass, or (failmask << 1) | 1
# (bit N-1 of failmask = check N). Sail 0.15 does not implement Smrnmi (mnstatus is an
# illegal CSR there), so the sail argument is accepted but the test is not run on it.
W=${1:-whisper}; S=${2:-spike}
cd "$(dirname "$0")"
out=$(timeout 120 "$W" --maxinst 100000 --config whisper.json --log mnstatus.elf 2>&1)
if echo "$out" | grep -q "Successful stop"; then
  echo "whisper  PASS"
else
  v=$(echo "$out" | grep -E ' sd +x10, 0x0\(x5\)' | tail -1 | awk '{print $8}')
  if [ -n "$v" ]; then echo "whisper  FAIL (failmask $(( (16#$v) >> 1 )))"; else echo "whisper  FAIL"; fi
fi
timeout 120 "$S" $(cat spike-args.txt) mnstatus.elf > /dev/null 2>&1; rc=$?
if [ $rc -eq 0 ]; then echo "spike    PASS"; else echo "spike    FAIL (failmask $rc)"; fi
echo "sail     not run (Sail 0.15 has no Smrnmi)"
