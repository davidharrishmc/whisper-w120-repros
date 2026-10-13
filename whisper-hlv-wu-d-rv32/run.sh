#!/bin/bash
# run.sh [whisper] [spike] [sail_riscv_sim]: run the self-checking tests on each simulator.
cd "$(dirname "$0")"
W=${1:-whisper}; S=${2:-spike}; L=${3:-sail_riscv_sim}
res() { if grep -q "RVCP-SUMMARY: TEST PASSED"; then echo PASS; else echo FAIL; fi; }
echo "== W120H_hlv_rv32-00"
echo "whisper: $(timeout 120 "$W" --maxinst 1000000 --config whisper.json W120H_hlv_rv32-00.whisper.elf 2>&1 | res)"
echo "spike:   $(timeout 120 "$S" --instructions=1000000 $(cat spike_args.txt) W120H_hlv_rv32-00.spike.elf 2>&1 | res)"
echo "sail:    $(timeout 120 "$L" --config sail.json W120H_hlv_rv32-00.sail.elf 2>&1 | res)"
