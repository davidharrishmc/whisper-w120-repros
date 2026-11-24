#!/bin/sh
# Usage: ./run.sh [path/to/whisper]    (default: whisper on PATH)
W=${1:-whisper}
cd "$(dirname "$0")" || exit 1

echo "=== rv64 01a (store-address trigger on the upper half)"
"$W" --maxinst 100000000:f --config whisper-rv64-max.json u04-atomics-whisper-01a.whisper-rv64-max.elf 2>&1 | grep -v "^Warning: vector\."

echo "=== rv64 01b (store-data trigger on the upper swap value)"
"$W" --maxinst 100000000:f --config whisper-rv64-max.json u04-atomics-whisper-01b.whisper-rv64-max.elf 2>&1 | grep -v "^Warning: vector\."

echo "=== rv64 01c (size-64 trigger at A on amocas.q)"
"$W" --maxinst 100000000:f --config whisper-rv64-max.json u04-atomics-whisper-01c.whisper-rv64-max.elf 2>&1 | grep -v "^Warning: vector\."

echo "=== rv32 01a"
"$W" --maxinst 100000000:f --config whisper-rv32-max.json u04-atomics-whisper-01a.whisper-rv32-max.elf 2>&1 | grep -v "^Warning: vector\."

echo "=== rv32 01b"
"$W" --maxinst 100000000:f --config whisper-rv32-max.json u04-atomics-whisper-01b.whisper-rv32-max.elf 2>&1 | grep -v "^Warning: vector\."

echo "=== rv32 01c (size-32 trigger at A on amocas.d)"
"$W" --maxinst 100000000:f --config whisper-rv32-max.json u04-atomics-whisper-01c.whisper-rv32-max.elf 2>&1 | grep -v "^Warning: vector\."
