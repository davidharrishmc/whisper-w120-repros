#!/bin/bash
# Usage: ./run.sh [whisper] [spike] [sail_riscv_sim]
# Runs the reproducer on each simulator and prints PASS or FAIL.
cd "$(dirname "$0")"
W=${1:-whisper}; S=${2:-spike}; A=${3:-sail_riscv_sim}
act() { if grep -q "RVCP-SUMMARY: TEST PASSED"; then echo PASS; else echo FAIL; fi; }
T=W120Inh_modes-00
echo "whisper: $(timeout 120 $W --maxinst 1000000 --config whisper.json $T-whisper.elf 2>&1 | act)"
timeout 120 $S $(cat spike-args.txt) $T-sail.elf > /dev/null 2>&1 && r=PASS || r=FAIL
echo "spike:   $r"
echo "sail:    $(timeout 120 $A --config sail.json $T-sail.elf 2>&1 | act)"
