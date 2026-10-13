#!/bin/bash
# run.sh [whisper]: run vsew128.elf on two vector configurations.
cd "$(dirname "$0")"
W=${1:-whisper}
for c in whisper-max-bytes-16 whisper-min-bytes-2; do
  echo "== $c.json: $(timeout 60 "$W" --maxinst 10000 --config $c.json vsew128.elf 2>&1 | grep -v '^Warning\|^  mask' | grep -m1 'stop\|Error')"
done
