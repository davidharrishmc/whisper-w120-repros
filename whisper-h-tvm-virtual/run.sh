#!/bin/bash
# run.sh [whisper]: run the self-checking test on Whisper (riscv-arch-test whisper-rv64-max config).
cd "$(dirname "$0")"
W=${1:-whisper}
T=whisper_tvm_virtual
if timeout 300 "$W" --maxinst 100000000:f --config whisper.json $T.elf 2>&1 | grep -q "RVCP-SUMMARY: TEST PASSED"; then
  echo "$T: PASS"; else echo "$T: FAIL"; fi
