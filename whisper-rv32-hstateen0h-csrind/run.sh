#!/bin/bash
# run.sh [whisper]: run the self-checking hstateen_encoding test on Whisper (riscv-arch-test whisper-rv32-max config).
cd "$(dirname "$0")"
W=${1:-whisper}
if timeout 300 "$W" --maxinst 100000000:f --config whisper-rv32.json hstateen_encoding.elf 2>&1 | grep -q "RVCP-SUMMARY: TEST PASSED"; then
  echo "hstateen_encoding rv32: PASS"; else echo "hstateen_encoding rv32: FAIL"; fi
timeout 300 "$W" --maxinst 100000000:f --config whisper-rv32.json hstateen_encoding.elf 2>&1 | grep -E "Test Info|Bad Value"
