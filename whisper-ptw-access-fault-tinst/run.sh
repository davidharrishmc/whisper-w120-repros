#!/bin/bash
# run.sh [path/to/whisper]: run tinst-ptw.elf on Whisper and print one PASS/FAIL line per case,
# then PASS or FAIL overall (exit status 0 = pass).
W=${1:-whisper}
case $W in */*) W=$(cd "$(dirname "$W")" && pwd)/$(basename "$W");; esac
cd "$(dirname "$0")" || exit 1
out=$(timeout 300 "$W" --maxinst 10000000:f --config whisper.json tinst-ptw.elf 2>&1)
echo "$out" | grep -E "^(PASS|FAIL) "
if echo "$out" | grep -q "Successful stop"; then echo PASS; exit 0; fi
echo FAIL; exit 1
