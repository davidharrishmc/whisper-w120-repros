#!/bin/sh
# Usage: ./run.sh [path/to/whisper]    (default: whisper on PATH)
W=${1:-whisper}
cd "$(dirname "$0")" || exit 1

echo "=== rv64, ACT config whisper-rv64-max, misa.C cleared at run time"
"$W" --maxinst 5000000 --config whisper-rv64-max.json --logfile v2-X1-ialign32-mtval.rv64.whisper-rv64-max.trace v2-X1-ialign32-mtval.rv64.elf 2>&1 | grep -v "^Warning: vector\."
echo "tohost = 0x$(grep -a "\[0x80001000[],]" v2-X1-ialign32-mtval.rv64.whisper-rv64-max.trace | tail -n 1 | awk '{print $8}')"   # 1 = pass

echo "=== rv32, ACT config whisper-rv32-max, misa.C cleared at run time"
"$W" --maxinst 5000000 --config whisper-rv32-max.json --logfile v2-X1-ialign32-mtval.rv32.whisper-rv32-max.trace v2-X1-ialign32-mtval.rv32.elf 2>&1 | grep -v "^Warning: vector\."
echo "tohost = 0x$(grep -a "\[0x80001000[],]" v2-X1-ialign32-mtval.rv32.whisper-rv32-max.trace | tail -n 1 | awk '{print $8}')"   # 1 = pass

