#!/bin/bash
# run.sh [whisper] [sail_riscv_sim]: run the self-checking tests on Whisper (riscv-arch-test whisper-rv64-max
# and whisper-rv32-max configs) and, if a Sail binary is given, the .sail.elf builds on Sail.
cd "$(dirname "$0")"
W=${1:-whisper}; L=$2
res() { if grep -q "RVCP-SUMMARY: TEST PASSED"; then echo PASS; else echo FAIL; fi; }
for t in rv32_ssamoswap-w_op.rv64 rv64_ssamoswap-w_op.rv64 rv32_ssamoswap-w_op.rv32; do
  x=${t##*.}
  echo "$t whisper: $(timeout 300 "$W" --maxinst 100000000:f --config whisper-$x.json $t.elf 2>&1 | res)"
  if [ -n "$L" ]; then echo "$t sail:    $(timeout 300 "$L" --config sail-$x.json $t.sail.elf 2>&1 | res)"; fi
done
