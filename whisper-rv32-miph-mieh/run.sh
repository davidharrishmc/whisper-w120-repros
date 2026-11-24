#!/bin/sh
# Usage: ./run.sh [path/to/whisper]    (default: whisper on PATH)
W=${1:-whisper}
cd "$(dirname "$0")" || exit 1

echo "=== rv32"
"$W" --maxinst 100000000:f --config whisper-rv32-max.json u30-aia-a-whisper-05.whisper-rv32-max.elf 2>&1 | grep -v "^Warning: vector\."
