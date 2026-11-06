#!/bin/bash
# run.sh [whisper] [sail_riscv_sim]: run the self-checking tests on Whisper (riscv-arch-test
# whisper-rv64-max config) and, if a Sail binary and sail.json are given, on Sail.
cd "$(dirname "$0")"
W=${1:-whisper}; L=$2; SJ=$3
res() { if grep -q "RVCP-SUMMARY: TEST PASSED"; then echo PASS; else echo FAIL; fi; }
for T in whisper_hfence_gvma_rs2_bit30 whisper_hfence_vvma_rs2_bit20; do
  echo "$T whisper: $(timeout 300 "$W" --maxinst 100000000:f --config whisper.json $T.elf 2>&1 | res)"
  if [ -n "$L" ]; then echo "$T sail:    $(timeout 300 "$L" --config "$SJ" $T.sail.elf 2>&1 | res)"; fi
done
