#!/bin/bash
# run.sh [path/to/whisper]: run the two-hart test on Whisper (--harts 2), deterministic and threaded.
# tohost: 1 = pass (hart 0's SC failed), 3 = FAIL (the SC succeeded after hart 1's write), 5 = setup problem.
# Exit status 0 = all pass.
W=${1:-whisper}
case $W in */*) W=$(cd "$(dirname "$W")" && pwd)/$(basename "$W");; esac
cd "$(dirname "$0")"
status=0
for elf in lrsc-cbo-zero-2h.elf lrsc-sw-control-2h.elf; do
  for mode in deterministic threaded; do
    extra=""; [ $mode = deterministic ] && extra="--deterministic 1:3 --seed 7"
    th=$(timeout 120 "$W" --harts 2 --quitany $extra --maxinst 2000000 --log --config whisper.json $elf 2>/dev/null |
         grep -a ' m 0000000080001000 ' | tail -1 | awk '{print $8}')
    case $((16#${th:-0})) in
      1) r="PASS (SC failed)";;
      3) r="FAIL (SC succeeded after the other hart's write)"; status=1;;
      5) r="SETUP PROBLEM"; status=1;;
      *) r="NO RESULT (tohost = '$th')"; status=1;;
    esac
    echo "$elf $mode: $r"
  done
done
if [ $status = 0 ]; then echo PASS; else echo FAIL; fi
exit $status
