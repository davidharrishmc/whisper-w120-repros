#!/bin/bash
# run.sh [whisper] [spike] [sail_riscv_sim]: run the self-checking tests on each simulator.
cd "$(dirname "$0")"
W=${1:-whisper}; S=${2:-spike}; L=${3:-sail_riscv_sim}
res() { if grep -q "RVCP-SUMMARY: TEST PASSED"; then echo PASS; else echo FAIL; fi; }
echo "== zkne Zkne-aes64ks1i-00"
echo "whisper: $(timeout 120 "$W" --maxinst 1000000 --config zkne/whisper.json zkne/Zkne-aes64ks1i-00.whisper.elf 2>&1 | res)"
echo "spike:   $(timeout 120 "$S" --instructions=1000000 $(cat zkne/spike_args.txt) zkne/Zkne-aes64ks1i-00.spike.elf 2>&1 | res)"
echo "sail:    $(timeout 120 "$L" --config zkne/sail.json zkne/Zkne-aes64ks1i-00.sail.elf 2>&1 | res)"
echo "== zkne Zkne-aes64ks2-00"
echo "whisper: $(timeout 120 "$W" --maxinst 1000000 --config zkne/whisper.json zkne/Zkne-aes64ks2-00.whisper.elf 2>&1 | res)"
echo "spike:   $(timeout 120 "$S" --instructions=1000000 $(cat zkne/spike_args.txt) zkne/Zkne-aes64ks2-00.spike.elf 2>&1 | res)"
echo "sail:    $(timeout 120 "$L" --config zkne/sail.json zkne/Zkne-aes64ks2-00.sail.elf 2>&1 | res)"
echo "== zknd Zknd-aes64ks1i-00"
echo "whisper: $(timeout 120 "$W" --maxinst 1000000 --config zknd/whisper.json zknd/Zknd-aes64ks1i-00.whisper.elf 2>&1 | res)"
echo "spike:   $(timeout 120 "$S" --instructions=1000000 $(cat zknd/spike_args.txt) zknd/Zknd-aes64ks1i-00.spike.elf 2>&1 | res)"
echo "sail:    $(timeout 120 "$L" --config zknd/sail.json zknd/Zknd-aes64ks1i-00.sail.elf 2>&1 | res)"
echo "== zknd Zknd-aes64ks2-00"
echo "whisper: $(timeout 120 "$W" --maxinst 1000000 --config zknd/whisper.json zknd/Zknd-aes64ks2-00.whisper.elf 2>&1 | res)"
echo "spike:   $(timeout 120 "$S" --instructions=1000000 $(cat zknd/spike_args.txt) zknd/Zknd-aes64ks2-00.spike.elf 2>&1 | res)"
echo "sail:    $(timeout 120 "$L" --config zknd/sail.json zknd/Zknd-aes64ks2-00.sail.elf 2>&1 | res)"
