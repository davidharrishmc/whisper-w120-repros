# vstopi ignores the priority numbers in hviprio1/hviprio2

Whisper reproducer, 2026-11-21. Found by a four-simulator spec review against riscv-isa-manual 3142f66f (plus
riscv-aia 9507866 and riscv-debug-spec 40e5c35); failing on Whisper master a0288feb (and on a5554a17).

## What is wrong

With VS-level SSI (1) and STI (5) pending and enabled, hvictl.VTI = 0, IPRIOM = 1, and hviprio1 giving
interrupt 1 priority 7 and interrupt 5 priority 3, vstopi reports IID 1 with IPRIO 255, the default order as if every
hviprio field were 0, although hviprio1 reads back the written values.

## Correct behavior

Candidate 4 of vstopi uses the priority numbers in hviprio1/hviprio2. Here interrupt 5 (number 3) beats
interrupt 1 (number 7): vstopi = (5 << 16) | 3. With the numbers swapped, vstopi = (1 << 16) | 3.

```
Case A: hviprio1 int1 = 7, int5 = 3    Expected: vstopi = 0x00050003   Observed: 0x000100ff
Case B: hviprio1 int1 = 3, int5 = 7    Expected: vstopi = 0x00010003   Observed: 0x000100ff
```

## How to run

```
./run.sh /path/to/whisper
```

Cases:
- rv64: `u30-aia-a-T-02.whisper-rv64-max.elf` with `whisper-rv64-max.json`
- rv32: `u30-aia-a-T-02.whisper-rv32-max.elf` with `whisper-rv32-max.json`

Files:
- `run.sh`: runs every case below on the Whisper binary given as argument.
- `u30-aia-a-T-02.whisper-rv64-max.elf` (+ `.objdump`)
- `u30-aia-a-T-02.whisper-rv32-max.elf` (+ `.objdump`)
- `whisper-rv64-max.json`: whisper.json used for the run
- `whisper-rv32-max.json`: whisper.json used for the run
- `src/`: test source (riscv-arch-test act4 `tests_ai` format with `sa.h`; built by the ACT framework for the config named in the file name; self-checking, prints `SA-MISMATCH` lines on failure)

## Output on Whisper master a5554a17 (key lines)

```
=== rv64
SA-MISMATCH: T-02 A: hviprio1 int1=7 int5=3: vstopi = IID 5, IPRIO 3 (VSLevel.adoc:460-463) expect=0x0000000000050003 got=0x00000000000100ff
SA-MISMATCH: T-02 B: hviprio1 int1=3 int5=7: vstopi = IID 1, IPRIO 3 expect=0x0000000000010003 got=0x00000000000100ff
RVCP-SUMMARY: TEST FAILED - Test File "u30-aia-a-T-02.S"
RVCP: Test Info: number of SA-MISMATCH soft-check failures (see the log)
Error: Failed stop: Hart 0: write to to-host
=== rv32
SA-MISMATCH: T-02 A: hviprio1 int1=7 int5=3: vstopi = IID 5, IPRIO 3 (VSLevel.adoc:460-463) expect=0x00050003 got=0x000100ff
SA-MISMATCH: T-02 B: hviprio1 int1=3 int5=7: vstopi = IID 1, IPRIO 3 expect=0x00010003 got=0x000100ff
RVCP-SUMMARY: TEST FAILED - Test File "u30-aia-a-T-02.S"
RVCP: Test Info: number of SA-MISMATCH soft-check failures (see the log)
Error: Failed stop: Hart 0: write to to-host
```
