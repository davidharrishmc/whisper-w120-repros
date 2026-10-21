#!/usr/bin/env bash
# Run vstip.elf on whisper (on PATH) with the time CSR absent and present.
# The exit value written to tohost is (wrong-case bitmask << 1) | 1; whisper prints "Successful stop" when it is 1.
set -u
cd "$(dirname "$0")"
for c in notime time; do
  echo "== $c.json"
  whisper --maxinst 100000 --config $c.json --log --logfile $c.trace vstip.elf
  echo "exit code $?"
  echo "hip reads: $(grep -c 'csrrs.*x10, hip' $c.trace); last hip value: $(grep 'csrrs.*x10, hip' $c.trace | tail -1 | awk '{print $8}')"
  echo "tohost: $(grep 'sd .*x5, 0x0(x6)' $c.trace | awk '{print $8}')"
done
