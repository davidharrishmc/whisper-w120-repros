# hviprio1 bytes reserved for interrupts 0, 4 and 8 are writable

Whisper reproducer, 2026-11-21. Found by a four-simulator spec review against riscv-isa-manual 3142f66f (plus
riscv-aia 9507866 and riscv-debug-spec 40e5c35); failing on Whisper master a0288feb (and on a5554a17).

## What is wrong

Writing all ones to hviprio1 reads back all ones, including the bytes for interrupts 0, 4 and 8 (RV64 bytes
0, 2, 4; RV32 hviprio1 bytes 0, 2 and hviprio1h byte 0).

## Correct behavior

Those bytes are "Reserved for priority number for interrupt 0/4/8; reads as zero".

```
csrw hviprio1, -1 (RV32 also hviprio1h)
  Expected: RV64 0xffffff00ff00ff00 (bytes 0, 2, 4 zero); RV32 hviprio1 0xff00ff00, hviprio1h 0xffffff00
  Observed: RV64 0xffffffffffffffff; RV32 0xffffffff, 0xffffffff
```

## How to run

```
./run.sh /path/to/whisper
```

Cases:
- rv64: `u30-aia-a-T-03.whisper-rv64-max.elf` with `whisper-rv64-max.json`
- rv32: `u30-aia-a-T-03.whisper-rv32-max.elf` with `whisper-rv32-max.json`

Files:
- `run.sh`: runs every case below on the Whisper binary given as argument.
- `u30-aia-a-T-03.whisper-rv64-max.elf` (+ `.objdump`)
- `u30-aia-a-T-03.whisper-rv32-max.elf` (+ `.objdump`)
- `whisper-rv64-max.json`: whisper.json used for the run
- `whisper-rv32-max.json`: whisper.json used for the run
- `src/`: test source (riscv-arch-test act4 `tests_ai` format with `sa.h`; built by the ACT framework for the config named in the file name; self-checking, prints `SA-MISMATCH` lines on failure)

## Output on Whisper master a5554a17 (key lines)

```
=== rv64
SA-MISMATCH: INFO T-03: hviprio1 after writing all ones expect=0x0000000000000000 got=0xffffffffffffffff
SA-MISMATCH: T-03: hviprio1 bytes 0, 2, 4 (interrupts 0, 4, 8) read as zero (VSLevel.adoc:236-245) expect=0x0000000000000000 got=0x000000ff00ff00ff
RVCP-SUMMARY: TEST FAILED - Test File "u30-aia-a-T-03.S"
RVCP: Test Info: number of SA-MISMATCH soft-check failures (see the log)
Error: Failed stop: Hart 0: write to to-host
=== rv32
SA-MISMATCH: INFO T-03: hviprio1 after writing all ones expect=0x00000000 got=0xffffffff
SA-MISMATCH: T-03: hviprio1 bytes 0, 2 (interrupts 0, 4) read as zero (VSLevel.adoc:236-245) expect=0x00000000 got=0x00ff00ff
SA-MISMATCH: INFO T-03: hviprio1h after writing all ones expect=0x00000000 got=0xffffffff
SA-MISMATCH: T-03: hviprio1h byte 0 (interrupt 8) reads as zero (VSLevel.adoc:244-245) expect=0x00000000 got=0x000000ff
RVCP-SUMMARY: TEST FAILED - Test File "u30-aia-a-T-03.S"
RVCP: Test Info: number of SA-MISMATCH soft-check failures (see the log)
Error: Failed stop: Hart 0: write to to-host
```
