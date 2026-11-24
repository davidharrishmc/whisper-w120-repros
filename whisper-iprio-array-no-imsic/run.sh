#!/bin/sh
# Usage: ./run.sh [path/to/whisper]    (default: whisper on PATH)
W=${1:-whisper}
cd "$(dirname "$0")" || exit 1

echo "=== rv64, ACT config whisper-rv64-m"
"$W" --maxinst 100000000:f --config whisper-rv64-m.json u30-aia-a-T-05.whisper-rv64-m.elf 2>&1 | grep -v "^Warning: vector\."

echo "=== rv32, ACT config whisper-rv32-mu"
"$W" --maxinst 100000000:f --config whisper-rv32-mu.json u30-aia-a-T-05.whisper-rv32-mu.elf 2>&1 | grep -v "^Warning: vector\."
