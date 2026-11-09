#!/bin/bash
# run.sh [path/to/whisper]: run the RV32 reproducer ELF on Whisper; print PASS or FAIL and the failed checks.
# whisper.json is the riscv-arch-test whisper-rv32-max configuration (mstatush.MBE writable).
# Exit status 0 = pass.
W=${1:-whisper}
case $W in */*) W=$(cd "$(dirname "$W")" && pwd)/$(basename "$W");; esac
cd "$(dirname "$0")"
for e in "MBE=1" "MBE=0"; do
  names+=("$e: the first amocas.d returns neither {A, B} nor {B, A}"
          "$e: the second amocas.d (compare value R) does not succeed"
          "$e: the second amocas.d stores {C, D} in the other order from the one in which the first read the pair"
          "$e: the third amocas.d does not return {C, D}")
done
elf=whisper-rv32-amocas-d-big-endian.elf
out=$(timeout 120 "$W" --maxinst 100000000:f --config whisper.json $elf 2>&1)
if echo "$out" | grep -q 'TEST PASSED'; then echo "$elf: PASS"; echo PASS; exit 0; fi
bad=$(echo "$out" | grep -o 'Bad Value: *0x[0-9a-fA-F]*' | awk '{print $3}')
if [ -z "$bad" ]; then echo "$elf: FAIL (no result)"; echo "$out" | tail -5; echo FAIL; exit 1; fi
echo "$elf: FAIL (failed-check bitmask $bad)"
for i in "${!names[@]}"; do (( (bad >> i) & 1 )) && echo "  bit $i: ${names[$i]}"; done
echo FAIL
exit 1
