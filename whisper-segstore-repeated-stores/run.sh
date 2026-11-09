#!/bin/bash
# run.sh path/to/whisper: run segstore_rv64.elf and segstore_rv32.elf on Whisper. Each prints field 0 of the
# segments of two segment stores (strided with stride 0, ordered indexed with all indices 0) on Whisper's
# console. Expected: "ABCD" for each store. Prints PASS or FAIL for each ELF (exit status 0 = pass).
cd "$(dirname "$0")"
W=${1:-whisper}
status=0
for x in 64 32; do
  out=$(timeout 60 "$W" --config whisper-rv$x.json segstore_rv$x.elf 2>/dev/null)
  echo "rv$x: console output:"
  echo "$out" | sed 's/^/    /'
  if [ "$out" = "$(printf 'ABCD\nABCD')" ]; then echo "rv$x: PASS"; else echo "rv$x: FAIL (expected ABCD twice)"; status=1; fi
done
exit $status
