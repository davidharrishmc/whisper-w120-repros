#!/bin/bash
# run.sh [whisper] [spike] [sail_riscv_sim]: run the self-checking test on each simulator.
cd "$(dirname "$0")"
W=${1:-whisper}; S=${2:-spike}; L=${3:-sail_riscv_sim}
T=Sv_H_sv32x4_fence_x4-00
res() { if grep -q "RVCP-SUMMARY: TEST PASSED"; then echo PASS; else echo FAIL; fi; }
echo "== $T"
echo "whisper: $(timeout 300 "$W" --maxinst 100000000:f --config whisper.json $T.whisper.elf 2>&1 | res)"
echo "spike:   $(timeout 300 "$S" --instructions=100000000 $(cat spike_args.txt) $T.spike.elf 2>&1 | res)"
echo "sail:    $(timeout 300 "$L" --config sail.json $T.sail.elf 2>&1 | res)"
