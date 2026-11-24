#!/bin/sh
# Usage: ./run.sh [path/to/whisper]    (default: whisper on PATH)
W=${1:-whisper}
cd "$(dirname "$0")" || exit 1

echo "=== rv64"
"$W" --maxinst 100000000:f --config whisper-rv64-max.json v2-u21w-01-pmp-tor.whisper-rv64-max.elf 2>&1 | grep -v "^Warning: vector\."

echo "=== rv32"
"$W" --maxinst 100000000:f --config whisper-rv32-max.json v2-u21w-01-pmp-tor.whisper-rv32-max.elf 2>&1 | grep -v "^Warning: vector\."
