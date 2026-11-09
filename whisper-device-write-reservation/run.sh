#!/bin/bash
# run.sh [path/to/whisper]: run the IOMMU device-write test on Whisper.
# tohost: 1 = pass (the SC failed), 3 = FAIL (the SC succeeded after the IOMMU wrote the bytes), 5 = setup problem.
# Exit status 0 = pass.
W=${1:-whisper}
case $W in */*) W=$(cd "$(dirname "$W")" && pwd)/$(basename "$W");; esac
cd "$(dirname "$0")"
th=$(timeout 120 "$W" --maxinst 200000 --log --config whisper-iommu.json lrsc-iommu-write.elf 2>/dev/null |
     grep -a ' m 0000000080001000 ' | tail -1 | awk '{print $8}')
case $((16#${th:-0})) in
  1) echo "lrsc-iommu-write.elf: PASS (SC failed)"; echo PASS; exit 0;;
  3) echo "lrsc-iommu-write.elf: FAIL (SC succeeded after the IOMMU wrote the bytes the LR read)";;
  5) echo "lrsc-iommu-write.elf: SETUP PROBLEM (the IOMMU did not write the word)";;
  *) echo "lrsc-iommu-write.elf: NO RESULT (tohost = '$th')";;
esac
echo FAIL
exit 1
