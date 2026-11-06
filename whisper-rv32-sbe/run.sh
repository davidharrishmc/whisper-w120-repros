#!/bin/bash
# run.sh [whisper] [sail_riscv_sim]: run the self-checking test on Whisper (riscv-arch-test whisper-rv32-max
# config) and, if a Sail binary is given, the .sail.elf build on Sail.
cd "$(dirname "$0")"
W=${1:-whisper}; L=$2
res() { if grep -q "RVCP-SUMMARY: TEST PASSED"; then echo PASS; else echo FAIL; fi; }
echo "mstatus_sbe_op whisper: $(timeout 300 "$W" --maxinst 100000000:f --config whisper-rv32.json mstatus_sbe_op.elf 2>&1 | res)"
if [ -n "$L" ]; then echo "mstatus_sbe_op sail:    $(timeout 300 "$L" --config sail-rv32.json mstatus_sbe_op.sail.elf 2>&1 | res)"; fi
