#!/bin/sh
# Usage: ./run.sh [path/to/whisper]    (default: whisper on PATH)
W=${1:-whisper}
cd "$(dirname "$0")" || exit 1

echo "=== rv64, whisper-rv64-mu + zicfiss + menvcfg mask 0x3000000fd (SSE writable)"
"$W" --maxinst 100000000:f --config whisper-rv64-mu-ssw.json u18-cfi-whisper-02.whisper-rv64-mu-ssw.elf 2>&1 | grep -v "^Warning: vector\."
