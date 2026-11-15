#!/bin/bash
# run.sh [path/to/whisper]: run mtip.elf on Whisper (whisper.json: rv64i, CLINT at 0x2000000), without and
# with --logfile. The program prints "FAIL n" on the HTIF console when check n fails. Prints PASS/FAIL per
# run and overall; exit status 0 = all passed.
cd "$(dirname "$0")"
W=${1:-whisper}
status=0
run() {
  out=$(timeout 60 "$W" --configfile whisper.json "$@" mtip.elf 2>&1)
  args="$*"; args=${args//$log/LOG}
  if echo "$out" | grep -q "Successful stop"; then
    echo "PASS  mtip.elf $args"
  else
    status=1
    echo "FAIL  mtip.elf $args : $(echo "$out" | grep -E '^FAIL' | head -1)"
  fi
}
log=$(mktemp)
run
run --logfile "$log"
rm -f "$log"
if [ $status = 0 ]; then echo PASS; else echo FAIL; fi
exit $status
