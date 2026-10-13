#!/bin/bash
# Usage: ./run.sh [whisper] [spike] [sail_riscv_sim]
# Runs the reproducer on each simulator and prints PASS or FAIL.
cd "$(dirname "$0")"
W=${1:-whisper}; S=${2:-spike}; A=${3:-sail_riscv_sim}
act() { if grep -q "RVCP-SUMMARY: TEST PASSED"; then echo PASS; else echo FAIL; fi; }
T=W120Tinfo_ro-00
echo "whisper (stock config whisper-stock.json): $(timeout 120 $W --maxinst 1000000 --config whisper-stock.json $T-whisper.elf 2>&1 | act)"
echo "whisper (whisper.json):                    $(timeout 120 $W --maxinst 1000000 --config whisper.json $T-whisper.elf 2>&1 | act)"
echo "spike:   $(timeout 120 $S $(cat spike-args.txt) $T-spike.elf 2>&1 | act)"
echo "sail:    $(timeout 120 $A --config sail.json $T-sail.elf 2>&1 | act)"
