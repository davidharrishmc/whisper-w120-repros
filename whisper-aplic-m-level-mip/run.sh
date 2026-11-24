#!/bin/sh
# Usage: ./run.sh [path/to/whisper]    (default: whisper on PATH)
W=${1:-whisper}
cd "$(dirname "$0")" || exit 1

echo "=== rv64 phantom SEIP (03)"
"$W" --maxinst 100000000:f --config whisper-rv64-max.json u30-aia-a-whisper-03.whisper-rv64-max.elf 2>&1 | grep -v "^Warning: vector\."

echo "=== rv64 lost MEIP (08)"
"$W" --maxinst 100000000:f --config whisper-rv64-max.json u30-aia-a-whisper-08.whisper-rv64-max.elf 2>&1 | grep -v "^Warning: vector\."

echo "=== rv32 phantom SEIP (03)"
"$W" --maxinst 100000000:f --config whisper-rv32-max.json u30-aia-a-whisper-03.whisper-rv32-max.elf 2>&1 | grep -v "^Warning: vector\."

echo "=== rv32 lost MEIP (08)"
"$W" --maxinst 100000000:f --config whisper-rv32-max.json u30-aia-a-whisper-08.whisper-rv32-max.elf 2>&1 | grep -v "^Warning: vector\."

echo "=== rv64 phantom SEIP on an M claim (T-04)"
"$W" --maxinst 100000000:f --config whisper-rv64-max.json u31-aia-b-T-04.whisper-rv64-max.elf 2>&1 | grep -v "^Warning: vector\."

echo "=== rv64 lost MEIP on eidelivery 1 -> 0x40000000 (T-06)"
"$W" --maxinst 100000000:f --config whisper-rv64-max.json u31-aia-b-T-06.whisper-rv64-max.elf 2>&1 | grep -v "^Warning: vector\."

echo "=== rv32 phantom SEIP on an M claim (T-04)"
"$W" --maxinst 100000000:f --config whisper-rv32-max.json u31-aia-b-T-04.whisper-rv32-max.elf 2>&1 | grep -v "^Warning: vector\."

echo "=== rv32 lost MEIP on eidelivery 1 -> 0x40000000 (T-06)"
"$W" --maxinst 100000000:f --config whisper-rv32-max.json u31-aia-b-T-06.whisper-rv32-max.elf 2>&1 | grep -v "^Warning: vector\."
