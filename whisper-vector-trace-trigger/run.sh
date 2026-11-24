#!/bin/sh
# Usage: ./run.sh [path/to/whisper]    (default: whisper on PATH)
W=${1:-whisper}
cd "$(dirname "$0")" || exit 1

echo "=== rv64 vle32.v"
"$W" --maxinst 100000000:f --config whisper-rv64-max.json u33-debug-b-whisper-02.whisper-rv64-max.elf 2>&1 | grep -v "^Warning: vector\."

echo "=== rv64 vlseg2e32.v / vlseg2e32ff.v / vluxseg2ei32.v"
"$W" --maxinst 100000000:f --config whisper-rv64-max.json u13-vec-a-whisper-01.whisper-rv64-max.elf 2>&1 | grep -v "^Warning: vector\."

echo "=== rv32 vle32.v"
"$W" --maxinst 100000000:f --config whisper-rv32-max.json u33-debug-b-whisper-02.whisper-rv32-max.elf 2>&1 | grep -v "^Warning: vector\."

echo "=== rv32 segment loads"
"$W" --maxinst 100000000:f --config whisper-rv32-max.json u13-vec-a-whisper-01.whisper-rv32-max.elf 2>&1 | grep -v "^Warning: vector\."
