#!/bin/bash
# run.sh [whisper] [spike] [sail_riscv_sim]: run the self-checking tests on each simulator.
cd "$(dirname "$0")"
W=${1:-whisper}; S=${2:-spike}; L=${3:-sail_riscv_sim}
res() { if grep -q "RVCP-SUMMARY: TEST PASSED"; then echo PASS; else echo FAIL; fi; }
echo "== rv64 W120H_svinval_absent-00"
echo "whisper: $(timeout 120 "$W" --maxinst 1000000 --config rv64/whisper.json rv64/W120H_svinval_absent-00.whisper.elf 2>&1 | res)"
echo "spike:   $(timeout 120 "$S" --instructions=1000000 $(cat rv64/spike_args.txt) rv64/W120H_svinval_absent-00.spike.elf 2>&1 | res)"
echo "sail:    $(timeout 120 "$L" --config rv64/sail.json rv64/W120H_svinval_absent-00.sail.elf 2>&1 | res)"
echo "== rv32 W120H_svinval_absent-00"
echo "whisper: $(timeout 120 "$W" --maxinst 1000000 --config rv32/whisper.json rv32/W120H_svinval_absent-00.whisper.elf 2>&1 | res)"
echo "spike:   $(timeout 120 "$S" --instructions=1000000 $(cat rv32/spike_args.txt) rv32/W120H_svinval_absent-00.spike.elf 2>&1 | res)"
echo "sail:    $(timeout 120 "$L" --config rv32/sail.json rv32/W120H_svinval_absent-00.sail.elf 2>&1 | res)"
