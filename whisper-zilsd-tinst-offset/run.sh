#!/bin/sh
# Usage: ./run.sh [path/to/whisper]    (default: whisper on PATH)
W=${1:-whisper}
cd "$(dirname "$0")" || exit 1

echo "=== rv32, whisper-rv32-max + zilsd (rr-u05-zilsd-w32)"
"$W" --maxinst 100000000:f --config rr-u05-zilsd-w32.json v10-u05-T-04.rr-u05-zilsd-w32.elf 2>&1 | grep -v "^Warning: vector\."
