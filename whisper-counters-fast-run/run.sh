#!/bin/bash
# run.sh [path/to/whisper]: run counters.elf on Whisper with an M-only hart (whisper-m.json) and an M+U hart
# (whisper-mu.json), each without and with --logfile. The program prints "FAIL n" on the HTIF console
# when check n fails. Prints PASS/FAIL per run and overall; exit status 0 = all passed.
cd "$(dirname "$0")"
W=${1:-whisper}
status=0
run() {   # run <config> [extra whisper args]
  cfg=$1; shift
  out=$(timeout 60 "$W" --configfile "$cfg" "$@" counters.elf 2>&1)
  args="$*"; args=${args//$log/LOG}
  if echo "$out" | grep -q "Successful stop"; then
    echo "PASS  $cfg $args"
  else
    status=1
    echo "FAIL  $cfg $args : $(echo "$out" | grep -E '^FAIL' | head -1)"
  fi
}
log=$(mktemp)
run whisper-m.json
run whisper-m.json --logfile "$log"
run whisper-mu.json
run whisper-mu.json --logfile "$log"
rm -f "$log"
if [ $status = 0 ]; then echo PASS; else echo FAIL; fi
exit $status
