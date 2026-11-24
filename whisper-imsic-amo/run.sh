#!/bin/sh
# Usage: ./run.sh [path/to/whisper]    (default: whisper on PATH)
W=${1:-whisper}
cd "$(dirname "$0")" || exit 1

echo "=== rv64"
"$W" --maxinst 100000000:f --config whisper-rv64-max.json u30-aia-a-T-06.whisper-rv64-max.elf 2>&1 | grep -v "^Warning: vector\."

echo "=== rv32"
"$W" --maxinst 100000000:f --config whisper-rv32-max.json u30-aia-a-T-06.whisper-rv32-max.elf 2>&1 | grep -v "^Warning: vector\."

echo "=== rv64 APLIC (u31 T-01)"
"$W" --maxinst 100000000:f --config whisper-rv64-max.json u31-aia-b-T-01.whisper-rv64-max.elf 2>&1 | grep -v "^Warning: vector\."

echo "=== rv32 APLIC (u31 T-01)"
"$W" --maxinst 100000000:f --config whisper-rv32-max.json u31-aia-b-T-01.whisper-rv32-max.elf 2>&1 | grep -v "^Warning: vector\."
