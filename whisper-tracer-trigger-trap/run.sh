#!/bin/bash
# run.sh [path/to/whisper]: run trig.elf on Whisper with the pctrace.so tracer extension, without and
# with --logfile. The program itself checks the breakpoint (it prints "FAIL n" if check n fails); this
# script also checks that the tracer received a TRAP record at `target`. Prints PASS/FAIL per run and
# overall; exit status 0 = all passed.
cd "$(dirname "$0")"
W=${1:-whisper}
target=$(riscv64-unknown-elf-nm trig.elf | awk '$3 == "target" { print $1 }')
status=0
run() {
  rm -f trace.txt
  out=$(timeout 60 "$W" --configfile whisper.json --tracerlib "$PWD/pctrace.so:trace.txt" "$@" trig.elf 2>&1)
  args="$*"; args=${args//$log/LOG}
  if ! echo "$out" | grep -q "Successful stop"; then
    status=1; echo "FAIL  trig.elf $args : program $(echo "$out" | grep -E '^FAIL' | head -1)"
  elif ! grep -q "^$target TRAP" trace.txt; then
    status=1; echo "FAIL  trig.elf $args : tracer got no TRAP record at target ($target); records: $(cut -c9- trace.txt | tr '\n' ' ')"
  else
    echo "PASS  trig.elf $args"
  fi
}
log=$(mktemp)
run
run --logfile "$log"
rm -f "$log" trace.txt
if [ $status = 0 ]; then echo PASS; else echo FAIL; fi
exit $status
