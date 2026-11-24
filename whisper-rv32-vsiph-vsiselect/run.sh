#!/bin/sh
# Usage: ./run.sh [path/to/whisper]    (default: whisper on PATH)
W=${1:-whisper}
cd "$(dirname "$0")" || exit 1

echo "=== rv32, stock ACT config"
"$W" --maxinst 100000000:f --config whisper-rv32-max.json u22-smmisc-whisper-01.whisper-rv32-max.elf 2>&1 | grep -v "^Warning: vector\."

echo "=== rv32, ACT config + smcdeleg/smcsrind (rr-u22-smmisc-w32)"
"$W" --maxinst 100000000:f --config rr-u22-smmisc-w32.json u22-smmisc-whisper-01.rr-u22-smmisc-w32.elf 2>&1 | grep -v "^Warning: vector\."
