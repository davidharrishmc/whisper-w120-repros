#!/bin/bash
# run.sh [whisper] [spike] [sail_riscv_sim] : run the self-checking ELF built for each simulator
cd "$(dirname "$0")"
W=${1:-whisper}; S=${2:-spike}; L=${3:-sail_riscv_sim}
res() { if grep -q "RVCP-SUMMARY: TEST PASSED" <<<"$1"; then echo PASS; else echo FAIL; fi; }
for c in nou32 nou64 scountovf; do
  o=$(timeout 120 $W --maxinst 1000000 --config $c.whisper.json $c.whisper.elf 2>&1); echo "whisper ($c): $(res "$o")"
  o=$(timeout 120 $(sed "s#^spike#$S#" $c.spike_cmd.txt) $c.spike.elf 2>&1); echo "spike ($c):   $(res "$o")"
  o=$(timeout 120 $L --config $c.sail.json $c.sail.elf 2>&1); echo "sail ($c):    $(res "$o")"
done
