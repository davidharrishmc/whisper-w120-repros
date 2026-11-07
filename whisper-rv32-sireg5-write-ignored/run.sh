#!/bin/bash
# run.sh [whisper]: run the self-checking test(s) on Whisper (riscv-arch-test whisper-rv32-max config with
# Smcsrind/Sscsrind/Smcdeleg/Ssccfg/Smctr/Ssctr enabled). A pass prints "RVCP-SUMMARY: TEST PASSED".
cd "$(dirname "$0")"
W=${1:-whisper}
for t in rv32_sireg5_write; do
  timeout 300 "$W" --maxinst 100000000:f --config whisper-rv32.json $t.elf 2>&1 | grep -E "RVCP-SUMMARY|Test Info|Bad Value"
done
