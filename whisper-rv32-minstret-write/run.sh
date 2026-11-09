#!/bin/bash
# run.sh [path/to/whisper]: run the RV32 reproducer ELF on Whisper; print PASS or FAIL and the failed checks.
# whisper.json is the riscv-arch-test whisper-rv32-max configuration. Exit status 0 = pass.
W=${1:-whisper}
case $W in */*) W=$(cd "$(dirname "$W")" && pwd)/$(basename "$W");; esac
cd "$(dirname "$0")"
names=("minstret = 0x10, csrw minstreth, 5: the next csrr minstret is not 0x10"
       "minstret = 0xffffffff, csrw minstreth, 7: the next csrr minstret is not 0xffffffff"
       "minstreth = 0, minstret = 0xffffffff, csrw minstret, 5: the next csrr minstreth is not 0"
       "riscv-tests instret_overflow: csrw minstret, -1; csrw minstreth, -1; nop: csrr minstret is not 0"
       "riscv-tests instret_overflow: the following csrr minstreth is not 0")
elf=whisper-rv32-minstret-write.elf
out=$(timeout 120 "$W" --maxinst 100000000:f --config whisper.json $elf 2>&1)
if echo "$out" | grep -q 'TEST PASSED'; then echo "$elf: PASS"; echo PASS; exit 0; fi
bad=$(echo "$out" | grep -o 'Bad Value: *0x[0-9a-fA-F]*' | awk '{print $3}')
if [ -z "$bad" ]; then echo "$elf: FAIL (no result)"; echo "$out" | tail -5; echo FAIL; exit 1; fi
echo "$elf: FAIL (failed-check bitmask $bad)"
for i in "${!names[@]}"; do (( (bad >> i) & 1 )) && echo "  bit $i: ${names[$i]}"; done
echo FAIL
exit 1
