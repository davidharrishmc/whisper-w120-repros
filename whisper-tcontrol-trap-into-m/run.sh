#!/bin/bash
# Usage: ./run.sh [whisper] [sail_riscv_sim]
# Each ELF writes 1 to tohost when the M-mode handler sees the original trap cause, else
# (mcause << 1) | 1. Spike is not run: it uses the MIE/SIE reentrancy option whenever S-mode
# exists, so it cannot model a hart with tcontrol and S-mode.
W=${1:-whisper}; L=${2:-sail_riscv_sim}
cd "$(dirname "$0")"
for t in etrigger itrigger; do
  out=$(timeout 120 "$W" --maxinst 100000 --config whisper.json --log $t.elf 2>&1)
  if echo "$out" | grep -q "Successful stop"; then
    w=PASS
  elif echo "$out" | grep -q "critical-error"; then
    w="FAIL (critical-error state: the breakpoint trapped again inside the M-mode handler)"
  else
    v=$(echo "$out" | grep -E ' sd +x10, 0x0\(x6\)' | tail -1 | awk '{print $8}')
    w="FAIL (tohost 0x$v)"
  fi
  if timeout 120 "$L" --config sail.json $t.elf 2>&1 | grep -q SUCCESS; then s=PASS; else s=FAIL; fi
  printf "%-9s whisper %s\n%-9s sail    %s\n" $t "$w" $t "$s"
done
