#!/bin/bash
# Usage: ./run.sh [whisper] [spike] [sail_riscv_sim]
# Runs each self-checking ELF on its simulator and prints PASS/FAIL.
W=${1:-whisper}; S=${2:-spike}; L=${3:-sail_riscv_sim}
cd "$(dirname "$0")"
for row in w120-rv64-mu w120-rv32-mu w120-rv64-h; do
  for t in W120Envcfg_stce-00; do
    [ -f $row/$t-whisper.elf ] || continue
    for sim in whisper spike sail; do
      case $sim in
        whisper) out=$(timeout 120 "$W" --maxinst 1000000 --config $row/whisper.json $row/$t-whisper.elf 2>&1);;
        spike)   out=$(timeout 120 "$S" $(cat $row/spike-args.txt) $row/$t-spike.elf 2>&1);;
        sail)    out=$(timeout 120 "$L" --config $row/sail.json $row/$t-sail.elf 2>&1);;
      esac
      if echo "$out" | grep -q "RVCP-SUMMARY: TEST PASSED"; then r=PASS; else r=FAIL; fi
      bin=$(echo "$out" | grep -o 'bin: [a-z0-9_]*' | head -1)
      printf "%-8s %-22s %-28s %s %s\n" $sim $row $t $r "${bin:+(first mismatch: $bin)}"
    done
  done
done
