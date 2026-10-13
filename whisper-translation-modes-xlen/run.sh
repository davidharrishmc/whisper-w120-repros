#!/bin/bash
# run.sh [whisper]: run the satp-mode ELFs on the five configurations.
cd "$(dirname "$0")"
W=${1:-whisper}
run() { echo "== $1 + $2: $(timeout 60 "$W" --maxinst 10000 --config $1.json $2 2>&1 | grep -v '^Warning\|^  mask' | grep -m1 'stop\|Error\|Assertion')"; }
run whisper-rv64-sv32 satpmode1.elf
run whisper-rv64-sv64 satpmode11.elf
run whisper-rv64-h-bare satpmode1.elf
run whisper-rv64-sv48-no-sv39 satpmode1.elf
run whisper-rv64-sv57-no-sv48 satpmode1.elf
