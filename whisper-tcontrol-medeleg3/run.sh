#!/bin/bash
# Usage: ./run.sh [whisper] [sail_riscv_sim]
# medeleg3.elf runs both checks and writes 1 to tohost when both pass, or (failmask << 1) | 1
# (bit N-1 of failmask = check N). Spike is not run: it uses the MIE/SIE reentrancy option
# whenever S-mode exists, so it cannot model a hart with tcontrol and S-mode.
W=${1:-whisper}; L=${2:-sail_riscv_sim}
cd "$(dirname "$0")"
out=$(timeout 120 "$W" --maxinst 100000 --config whisper.json --log medeleg3.elf 2>&1)
if echo "$out" | grep -q "Successful stop"; then
  echo "whisper  PASS"
else
  v=$(echo "$out" | grep -E ' sd +x10, 0x0\(x6\)' | tail -1 | awk '{print $8}')
  if [ -n "$v" ]; then echo "whisper  FAIL (failmask $(( (16#$v) >> 1 )))"; else echo "whisper  FAIL"; fi
fi
if timeout 120 "$L" --config sail.json medeleg3.elf 2>&1 | grep -q SUCCESS; then echo "sail     PASS"; else echo "sail     FAIL"; fi
