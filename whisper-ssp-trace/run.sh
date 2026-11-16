#!/bin/bash
# run.sh [path/to/whisper]: run ssp.elf on Whisper with --logfile. The program checks the ssp values
# itself (it prints "FAIL n" if check n fails). This script also checks that the log reports the ssp
# write (CSR 0x011) on the sspush and on the sspopchk. Prints PASS/FAIL per check and overall; exit
# status 0 = all passed.
cd "$(dirname "$0")"
W=${1:-whisper}
log=$(mktemp)
status=0
out=$(timeout 60 "$W" --configfile whisper.json --logfile "$log" ssp.elf 2>&1)
if echo "$out" | grep -q "Successful stop"; then
  echo "PASS  program (ssp values)"
else
  status=1; echo "FAIL  program: $(echo "$out" | grep -E '^FAIL' | head -1)"
fi
for sym in push pop; do
  pc=$(riscv64-unknown-elf-nm ssp.elf | awk -v s=$sym '$3 == s { print $1 }')
  lines=$(grep -E "^#[0-9]+ +[0-9]+ +[A-Z]+ +$pc " "$log")
  if echo "$lines" | grep -q " c 0000000000000011 "; then
    echo "PASS  log reports ssp on $sym ($pc): $(echo "$lines" | grep ' c 0000000000000011 ' | awk '{print $8}')"
  else
    status=1; echo "FAIL  log reports no ssp write on $sym ($pc):"; echo "$lines" | sed 's/^/        /'
  fi
done
rm -f "$log"
if [ $status = 0 ]; then echo PASS; else echo FAIL; fi
exit $status
