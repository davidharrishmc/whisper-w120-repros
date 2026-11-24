#!/bin/sh
# Usage: ./run.sh [path/to/whisper]    (default: whisper on PATH)
W=${1:-whisper}
cd "$(dirname "$0")" || exit 1

echo "=== rv64, dcsr preset ebreakm = 1 (whisper-rv64-ebmall)"
"$W" --maxinst 5000000 --config whisper-rv64-ebmall.json --logfile u32-debug-a-T-03.rv64.whisper-rv64-ebmall.trace u32-debug-a-T-03.rv64.elf 2>&1 | grep -v "^Warning: vector\."
echo "tohost = 0x$(grep -a "\[0x80002000[],]" u32-debug-a-T-03.rv64.whisper-rv64-ebmall.trace | tail -n 1 | awk '{print $8}')"   # 1 = pass

echo "=== rv32, dcsr preset ebreakm = 1 (whisper-rv32-ebmall)"
"$W" --maxinst 5000000 --config whisper-rv32-ebmall.json --logfile u32-debug-a-T-03.rv32.whisper-rv32-ebmall.trace u32-debug-a-T-03.rv32.elf 2>&1 | grep -v "^Warning: vector\."
echo "tohost = 0x$(grep -a "\[0x80002000[],]" u32-debug-a-T-03.rv32.whisper-rv32-ebmall.trace | tail -n 1 | awk '{print $8}')"   # 1 = pass
