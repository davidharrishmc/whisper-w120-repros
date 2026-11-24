#!/bin/sh
# Usage: ./run.sh [path/to/whisper]    (default: whisper on PATH)
W=${1:-whisper}
cd "$(dirname "$0")" || exit 1

echo "=== rv64 vsip/vsie with VTI = 1"
"$W" --maxinst 100000000:f --config whisper-rv64-max.json u30-aia-a-whisper-01.whisper-rv64-max.elf 2>&1 | grep -v "^Warning: vector\."

echo "=== rv32 vsip/vsie/vsiph/vsieh with VTI = 1"
"$W" --maxinst 100000000:f --config whisper-rv32-max.json u30-aia-a-whisper-01.whisper-rv32-max.elf 2>&1 | grep -v "^Warning: vector\."

echo "=== rv32 vsiph/vsieh before any hvictl write"
"$W" --maxinst 100000000:f --config whisper-rv32-max.json u23-smstateen-T-06.whisper-rv32-max.elf 2>&1 | grep -v "^Warning: vector\."
