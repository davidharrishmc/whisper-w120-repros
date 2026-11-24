#!/bin/sh
# Usage: ./run.sh [path/to/whisper]    (default: whisper on PATH)
W=${1:-whisper}
cd "$(dirname "$0")" || exit 1

echo "=== rv64, stock ACT config whisper-rv64-max"
"$W" --maxinst 100000000:f --config whisper-rv64-max.json u22-smmisc-T-B4.whisper-rv64-max.elf 2>&1 | grep -v "^Warning: vector\."

echo "=== rv64, ACT config + nmi_vec/nmi_exception_vec (rr-u22-smmisc-w64)"
"$W" --maxinst 100000000:f --config rr-u22-smmisc-w64.json u22-smmisc-T-B4.rr-u22-smmisc-w64.elf 2>&1 | grep -v "^Warning: vector\."

echo "=== rv32, ACT config + nmi vectors (rr-u22-smmisc-w32)"
"$W" --maxinst 100000000:f --config rr-u22-smmisc-w32.json u22-smmisc-T-B4.rr-u22-smmisc-w32.elf 2>&1 | grep -v "^Warning: vector\."
