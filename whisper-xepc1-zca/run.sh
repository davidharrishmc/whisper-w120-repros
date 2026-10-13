#!/bin/bash
# run.sh [whisper] [spike] [sail_riscv_sim] : run the self-checking ELF built for each simulator
cd "$(dirname "$0")"
W=${1:-whisper}; S=${2:-spike}; L=${3:-sail_riscv_sim}
res() { if grep -q "RVCP-SUMMARY: TEST PASSED" <<<"$1"; then echo PASS; else echo FAIL; fi; }
o=$(timeout 120 $W --maxinst 1000000 --config whisper.json whisper.elf 2>&1); echo "whisper: $(res "$o")"
o=$(timeout 120 $(sed "s#^spike#$S#" spike_cmd.txt) spike.elf 2>&1); echo "spike:   $(res "$o")"
o=$(timeout 120 $L --config sail.json sail.elf 2>&1); echo "sail:    $(res "$o")"
