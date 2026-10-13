#!/bin/bash
# run.sh [whisper]: write all ones to hgeie (interactive poke) and read it back.
cd "$(dirname "$0")"
W=${1:-whisper}
for c in whisper-guests-only whisper-count-mismatch whisper-guests-64; do
  echo "== $c.json"
  timeout 60 "$W" --interactive --config $c.json < cmds.txt 2>&1 | grep -v "^Warning\|^  mask" | tail -3
done
