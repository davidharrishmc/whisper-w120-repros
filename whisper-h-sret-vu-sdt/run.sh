#!/bin/bash
# run.sh [whisper]: run the self-checking sret_dt test on Whisper (riscv-arch-test whisper-rv64-max and
# whisper-rv32-max configs), then diag_sdt2, which always fails so that it prints vsstatus after SRET to VU.
cd "$(dirname "$0")"
W=${1:-whisper}
for x in 64 32; do
  if timeout 300 "$W" --maxinst 100000000:f --config whisper-rv$x.json sret_dt.rv$x.elf 2>&1 | grep -q "RVCP-SUMMARY: TEST PASSED"; then
    echo "sret_dt rv$x: PASS"; else echo "sret_dt rv$x: FAIL"; fi
done
echo "diag_sdt2 (vsstatus after SRET into VU; SDT is bit 24):"
timeout 300 "$W" --maxinst 100000000:f --config whisper-rv64.json diag_sdt2.elf 2>&1 | grep "Bad Value"
