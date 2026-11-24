# The exception for VS-mode sireg2 (vsiselect 0x70) and for VS sireg with hstateen0.IMSIC = 0 depends on the HS-level siselect

Whisper reproducer, 2026-11-21. Found by a four-simulator spec review against riscv-isa-manual 3142f66f (plus
riscv-aia 9507866 and riscv-debug-spec 40e5c35); failing on Whisper master a0288feb (and on a5554a17).

## What is wrong

With mstateen0 all ones except AIA, hstateen0 all ones, hstatus.VGEIN = 1, vsiselect = 0x70 and the HS-level
siselect = 0x30: (a) VS-mode `csrr sireg2` raises illegal-instruction; (b) with hstateen0.IMSIC = 0 as well, VS-mode
`csrr sireg` raises illegal-instruction. With HS siselect = 0x70 and everything else the same, both raise
virtual-instruction. The VS access never uses the HS siselect.

## Correct behavior

Both accesses raise virtual-instruction (22), whatever the HS-level siselect holds: (a) by CSRs.adoc:369 (see
the previous issue); (b) because hstateen0.IMSIC = 0 makes vsiselect 0x70-0xFF an inaccessible register at VS level,
and a VS access to sireg then raises virtual-instruction.

```
vsiselect = 0x70, mstateen0 = ~AIA, VS-mode
  (a) csrr sireg2, HS siselect = 0x30                       Expected: 22   Observed: illegal instruction (2)
  (b) csrr sireg, hstateen0.IMSIC = 0, HS siselect = 0x30   Expected: 22   Observed: 2
  (a), (b) with HS siselect = 0x70                          Expected: 22   Observed: 22
```

## How to run

```
./run.sh /path/to/whisper
```

Cases:
- rv64: `u30-aia-a-whisper-02.whisper-rv64-max.elf` with `whisper-rv64-max.json`
- rv32: `u30-aia-a-whisper-02.whisper-rv32-max.elf` with `whisper-rv32-max.json`

Files:
- `run.sh`: runs every case below on the Whisper binary given as argument.
- `u30-aia-a-whisper-02.whisper-rv64-max.elf` (+ `.objdump`)
- `u30-aia-a-whisper-02.whisper-rv32-max.elf` (+ `.objdump`)
- `whisper-rv64-max.json`: whisper.json used for the run
- `whisper-rv32-max.json`: whisper.json used for the run
- `src/`: test source (riscv-arch-test act4 `tests_ai` format with `sa.h`; built by the ACT framework for the config named in the file name; self-checking, prints `SA-MISMATCH` lines on failure)

## Output on Whisper master a5554a17 (key lines)

```
=== rv64
SA-MISMATCH: W02a: VS sireg2, vsiselect 0x70, mstateen0.AIA=0, HS siselect 0x30: virtual instruction (CSRs.adoc:369) expect=0x0000000000001316 got=0x0000000000001302
SA-MISMATCH: W02b: VS sireg, vsiselect 0x70, hstateen0.IMSIC=0, mstateen0.AIA=0, HS siselect 0x30: virtual instruction (CSRs.adoc:439, :352) expect=0x0000000000001316 got=0x0000000000001302
RVCP-SUMMARY: TEST FAILED - Test File "u30-aia-a-whisper-02.S"
RVCP: Test Info: number of SA-MISMATCH soft-check failures (see the log)
Error: Failed stop: Hart 0: write to to-host
=== rv32
SA-MISMATCH: W02a: VS sireg2, vsiselect 0x70, mstateen0.AIA=0, HS siselect 0x30: virtual instruction (CSRs.adoc:369) expect=0x00001316 got=0x00001302
SA-MISMATCH: W02b: VS sireg, vsiselect 0x70, hstateen0.IMSIC=0, mstateen0.AIA=0, HS siselect 0x30: virtual instruction (CSRs.adoc:439, :352) expect=0x00001316 got=0x00001302
RVCP-SUMMARY: TEST FAILED - Test File "u30-aia-a-whisper-02.S"
RVCP: Test Info: number of SA-MISMATCH soft-check failures (see the log)
Error: Failed stop: Hart 0: write to to-host
```
