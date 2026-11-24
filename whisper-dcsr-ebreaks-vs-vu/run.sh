#!/bin/sh
# Usage: ./run.sh [path/to/whisper]    (default: whisper on PATH)
W=${1:-whisper}
cd "$(dirname "$0")" || exit 1

echo "=== rv64, dcsr reset 0x40003003 (ebreaks = ebreaku = 1)"
"$W" --maxinst 5000000 --config whisper-rv64-ebreaks.json --logfile v2-u21w-05-ebreak-vs-vu.rv64.whisper-rv64-ebreaks.trace v2-u21w-05-ebreak-vs-vu.rv64.elf 2>&1 | grep -v "^Warning: vector\."
echo "tohost = 0x$(grep -a "\[0x80001000[],]" v2-u21w-05-ebreak-vs-vu.rv64.whisper-rv64-ebreaks.trace | tail -n 1 | awk '{print $8}')"   # 1 = pass

echo "=== rv64, dcsr reset 0x40001003 (ebreaku = 1)"
"$W" --maxinst 5000000 --config whisper-rv64-ebreaku.json --logfile v2-u21w-05-ebreak-vs-vu.rv64.whisper-rv64-ebreaku.trace v2-u21w-05-ebreak-vs-vu.rv64.elf 2>&1 | grep -v "^Warning: vector\."
echo "tohost = 0x$(grep -a "\[0x80001000[],]" v2-u21w-05-ebreak-vs-vu.rv64.whisper-rv64-ebreaku.trace | tail -n 1 | awk '{print $8}')"   # 1 = pass

echo "=== rv32, dcsr reset 0x40003003"
"$W" --maxinst 5000000 --config whisper-rv32-ebreaks.json --logfile v2-u21w-05-ebreak-vs-vu.rv32.whisper-rv32-ebreaks.trace v2-u21w-05-ebreak-vs-vu.rv32.elf 2>&1 | grep -v "^Warning: vector\."
echo "tohost = 0x$(grep -a "\[0x80001000[],]" v2-u21w-05-ebreak-vs-vu.rv32.whisper-rv32-ebreaks.trace | tail -n 1 | awk '{print $8}')"   # 1 = pass

echo "=== rv64, control: stock ACT config (dcsr.ebreak* = 0)"
"$W" --maxinst 5000000 --config whisper-rv64-max.json --logfile v2-u21w-05-ebreak-vs-vu.rv64.whisper-rv64-max.trace v2-u21w-05-ebreak-vs-vu.rv64.elf 2>&1 | grep -v "^Warning: vector\."
echo "tohost = 0x$(grep -a "\[0x80001000[],]" v2-u21w-05-ebreak-vs-vu.rv64.whisper-rv64-max.trace | tail -n 1 | awk '{print $8}')"   # 1 = pass
