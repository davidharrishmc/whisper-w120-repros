# Zilsd LD/SD write an mtinst/htinst Addr. Offset that is neither 0 nor xtval - EA (and print "Larger than 7 offset")

Whisper reproducer, 2026-11-21. Found by a four-simulator spec review against riscv-isa-manual 3142f66f (plus
riscv-aia 9507866 and riscv-debug-spec 40e5c35); failing on Whisper master a0288feb (and on a5554a17).

## What is wrong

For a Zilsd `ld`/`sd` that faults on its second word (xtval = EA+4), Whisper writes the transformed LD/SD with
Addr. Offset 0 (e.g. mtinst = 0x00003a03 for `ld x20`). For an LD that takes an address-misaligned trap (xtval = EA) it
writes an offset derived from the previous instruction's address and prints "Error: Hart::createTrapInst: Larger than 7
offset: N" on stderr. Seen in mtinst (trap to M) and htinst (trap to HS).

## Correct behavior

mtinst is 0, or the transformed instruction with Addr. Offset = xtval - EA: 4 for a fault on the second word,
0 for a misaligned trap. (If the hypervisor chapter's LD/SD transformation does not cover the RV32 pair forms, only 0 is
legal; Whisper's values are wrong under either reading.)

```
M1: ld x20, 0(P-4), page P PMP-denied (fault on the second word, xtval = P)
  Expected: mtinst = 0 or 0x00023a03 (offset 4)   Observed: 0x00003a03 (offset 0)
M2: sd x20, 0(P-4): same (offset 0, expected 0 or 4)
M3: ld x20, 0(A+0x101) misaligned trap (xtval = EA)
  Expected: mtinst = 0 or offset 0   Observed: offset 1, stderr "Larger than 7 offset: 3297"
```

## How to run

```
./run.sh /path/to/whisper
```

Cases:
- rv32, whisper-rv32-max + zilsd (rr-u05-zilsd-w32): `v10-u05-T-04.rr-u05-zilsd-w32.elf` with `rr-u05-zilsd-w32.json`

Files:
- `run.sh`: runs every case below on the Whisper binary given as argument.
- `v10-u05-T-04.rr-u05-zilsd-w32.elf` (+ `.objdump`)
- `rr-u05-zilsd-w32.json`: whisper.json used for the run
- `src/`: test source (riscv-arch-test act4 `tests_ai` format with `sa.h`; built by the ACT framework for the config named in the file name; self-checking, prints `SA-MISMATCH` lines on failure)

## Output on Whisper master a5554a17 (key lines)

```
=== rv32, whisper-rv32-max + zilsd (rr-u05-zilsd-w32)
SA-MISMATCH: M1 ld: xtinst in {0, transformed (offset = xtval-EA)} (difference) expect=0x00000000 got=0xfffe0000
SA-MISMATCH: M2 sd: xtinst in {0, transformed (offset = xtval-EA)} (difference) expect=0x00000000 got=0xfffe0000
Error: Hart::createTrapInst: Larger than 7 offset: 3297
SA-MISMATCH: M3 misaligned ld: xtinst in {0, transformed (offset = xtval-EA)} (difference) expect=0x00000000 got=0x00008000
RVCP-SUMMARY: TEST FAILED - Test File "v10-u05-T-04.S"
RVCP: Test Info: number of SA-MISMATCH soft-check failures (see the log)
Error: Failed stop: Hart 0: write to to-host
```
