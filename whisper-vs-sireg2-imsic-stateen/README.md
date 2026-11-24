# VS-mode sireg2-sireg6 with vsiselect 0x70-0xFF raise illegal-instruction when mstateen0.IMSIC = 0 (should be virtual-instruction)

Whisper reproducer, 2026-11-21. Found by a four-simulator spec review against riscv-isa-manual 3142f66f (plus
riscv-aia 9507866 and riscv-debug-spec 40e5c35); failing on Whisper master a0288feb (and on a5554a17).

## What is wrong

With mstateen0.CSRIND = mstateen0.AIA = 1, mstateen0.IMSIC = 0, hstateen0 all ones, hstatus.VGEIN = 1 and
vsiselect = 0x70, VS-mode `csrr sireg2` raises illegal-instruction (2).

## Correct behavior

VS-mode accesses to sireg2-sireg6 with vsiselect in 0x30-0x3F or 0x70-0xFF raise virtual-instruction (22).
Only mstateen0.CSRIND overrides that; the IMSIC and AIA stateen bits do not, because sireg2-6 at 0x70-0xFF access no
IMSIC state (AIA author's ruling, aia#103 and aia#151).

```
mstateen0 = ~IMSIC, hstateen0 = ~0, VGEIN = 1, vsiselect = 0x70, VS-mode csrr sireg2
  Expected: virtual instruction (22)
  Observed: illegal instruction (2)
Controls: VS csrr sireg with mstateen0.IMSIC = 0 -> 2 (correct); with mstateen0 = ~0, VS sireg2 -> 22 (correct)
```

## How to run

```
./run.sh /path/to/whisper
```

Cases:
- rv64: `u30-aia-a-T-01.whisper-rv64-max.elf` with `whisper-rv64-max.json`
- rv32: `u30-aia-a-T-01.whisper-rv32-max.elf` with `whisper-rv32-max.json`

Files:
- `run.sh`: runs every case below on the Whisper binary given as argument.
- `u30-aia-a-T-01.whisper-rv64-max.elf` (+ `.objdump`)
- `u30-aia-a-T-01.whisper-rv32-max.elf` (+ `.objdump`)
- `whisper-rv64-max.json`: whisper.json used for the run
- `whisper-rv32-max.json`: whisper.json used for the run
- `src/`: test source (riscv-arch-test act4 `tests_ai` format with `sa.h`; built by the ACT framework for the config named in the file name; self-checking, prints `SA-MISMATCH` lines on failure)

## Output on Whisper master a5554a17 (key lines)

```
=== rv64
SA-MISMATCH: T-01: VS csrr sireg2, vsiselect 0x70, mstateen0.IMSIC=0: virtual instruction (CSRs.adoc:369, aia#103) expect=0x0000000000001316 got=0x0000000000001302
RVCP-SUMMARY: TEST FAILED - Test File "u30-aia-a-T-01.S"
RVCP: Test Info: number of SA-MISMATCH soft-check failures (see the log)
Error: Failed stop: Hart 0: write to to-host
=== rv32
SA-MISMATCH: T-01: VS csrr sireg2, vsiselect 0x70, mstateen0.IMSIC=0: virtual instruction (CSRs.adoc:369, aia#103) expect=0x00001316 got=0x00001302
RVCP-SUMMARY: TEST FAILED - Test File "u30-aia-a-T-01.S"
RVCP: Test Info: number of SA-MISMATCH soft-check failures (see the log)
Error: Failed stop: Hart 0: write to to-host
```
