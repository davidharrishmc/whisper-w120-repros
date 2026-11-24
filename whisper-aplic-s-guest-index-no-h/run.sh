#!/bin/sh
# Usage: ./run.sh [path/to/whisper]    (default: whisper on PATH)
W=${1:-whisper}
cd "$(dirname "$0")" || exit 1

echo "=== rv64, S without H (whisper-rv64-noh = whisper-rv64-max minus H)"
"$W" --maxinst 5000000 --config whisper-rv64-noh.json --logfile u31-aia-b-T-07b.noh.rv64.whisper-rv64-noh.trace u31-aia-b-T-07b.noh.rv64.elf 2>&1 | grep -v "^Warning: vector\."
echo "tohost = 0x$(grep -a "\[0x80002000[],]" u31-aia-b-T-07b.noh.rv64.whisper-rv64-noh.trace | tail -n 1 | awk '{print $8}')"   # 1 = pass

echo "=== rv32, S without H (whisper-rv32-noh)"
"$W" --maxinst 5000000 --config whisper-rv32-noh.json --logfile u31-aia-b-T-07b.noh.rv32.whisper-rv32-noh.trace u31-aia-b-T-07b.noh.rv32.elf 2>&1 | grep -v "^Warning: vector\."
echo "tohost = 0x$(grep -a "\[0x80002000[],]" u31-aia-b-T-07b.noh.rv32.whisper-rv32-noh.trace | tail -n 1 | awk '{print $8}')"   # 1 = pass

echo "=== rv64, control with H (whisper-rv64-h = whisper-rv64-max, GEILEN 63): Guest Index 5 held"
"$W" --maxinst 5000000 --config whisper-rv64-h.json --logfile u31-aia-b-T-07b.h.rv64.whisper-rv64-h.trace u31-aia-b-T-07b.h.rv64.elf 2>&1 | grep -v "^Warning: vector\."
echo "tohost = 0x$(grep -a "\[0x80002000[],]" u31-aia-b-T-07b.h.rv64.whisper-rv64-h.trace | tail -n 1 | awk '{print $8}')"   # 1 = pass
