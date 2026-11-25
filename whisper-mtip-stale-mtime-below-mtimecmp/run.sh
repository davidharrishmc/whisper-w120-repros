#!/bin/sh
# Usage: ./run.sh [path/to/whisper]    (default: whisper on PATH)
# Runs every case without a trace file and with --logfile. Prints the SA-MISMATCH / FAIL lines of each run, then
# one PASS/FAIL line per run and overall. Exit status 0 = all passed.
W=${1:-whisper}
cd "$(dirname "$0")" || exit 1
status=0
run() {  # config elf [extra whisper options]
  cfg=$1; elf=$2; shift 2
  out=$(timeout 300 "$W" --maxinst 100000000:f --config "$cfg" "$@" "$elf" 2>&1)
  echo "$out" | grep -E "^SA-MISMATCH|^FAIL [0-9]"
  if echo "$out" | grep -q "Successful stop"; then echo "PASS  $elf $*"; else status=1; echo "FAIL  $elf $*"; fi
}
for x in 64 32; do
  for t in mtime-mtip mtime-stip; do
    run whisper-rv$x-max.json $t.whisper-rv$x-max.elf
    run whisper-rv$x-max.json $t.whisper-rv$x-max.elf --logfile /dev/null
  done
done
for t in mtime-write mtime-wrap; do
  run bare-rv64.json $t.bare-rv64.elf
  run bare-rv64.json $t.bare-rv64.elf --logfile /dev/null
done
if [ $status = 0 ]; then echo PASS; else echo FAIL; fi
exit $status
