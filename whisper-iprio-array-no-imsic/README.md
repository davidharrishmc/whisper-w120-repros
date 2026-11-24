# Smaia without an IMSIC: M-mode accesses to the iprio array (miselect 0x30-0x3F) raise illegal-instruction

Whisper reproducer, 2026-11-21. Found by a four-simulator spec review against riscv-isa-manual 3142f66f (plus
riscv-aia 9507866 and riscv-debug-spec 40e5c35); failing on Whisper master a0288feb (and on a5554a17).

## What is wrong

On a hart with Smaia and no IMSIC (the ACT -m and -mu configs), every M-mode access to mireg with miselect
0x30-0x3F (the machine-level iprio array) raises illegal-instruction. The max configs, which have an IMSIC, are right.

## Correct behavior

The iprio array is defined for every Smaia hart; its bytes may be read-only zero, but the registers exist.
Only odd selects 0x31-0x3F on RV64 (and 0x70-0xFF without an IMSIC) raise illegal-instruction.

```
M-mode, miselect = 0x30: csrr mireg / csrw mireg; miselect = 0x3E (RV32 also 0x3F): csrr mireg
  Expected: no trap (value may read 0)
  Observed: illegal instruction (2)
Control (RV64): miselect = 0x31 -> illegal instruction (correct)
```

## How to run

```
./run.sh /path/to/whisper
```

Cases:
- rv64, ACT config whisper-rv64-m: `u30-aia-a-T-05.whisper-rv64-m.elf` with `whisper-rv64-m.json`
- rv32, ACT config whisper-rv32-mu: `u30-aia-a-T-05.whisper-rv32-mu.elf` with `whisper-rv32-mu.json`

Files:
- `run.sh`: runs every case below on the Whisper binary given as argument.
- `u30-aia-a-T-05.whisper-rv64-m.elf` (+ `.objdump`)
- `u30-aia-a-T-05.whisper-rv32-mu.elf` (+ `.objdump`)
- `whisper-rv64-m.json`: whisper.json used for the run
- `whisper-rv32-mu.json`: whisper.json used for the run
- `src/`: test source (riscv-arch-test act4 `tests_ai` format with `sa.h`; built by the ACT framework for the config named in the file name; self-checking, prints `SA-MISMATCH` lines on failure)

## Output on Whisper master a5554a17 (key lines)

```
=== rv64, ACT config whisper-rv64-m
SA-MISMATCH: T-05: M csrr mireg, miselect 0x30 (iprio0): no trap (MSLevel.adoc:239-318) expect=0x00000000000000ff got=0x0000000000001302
SA-MISMATCH: T-05: M csrw mireg, miselect 0x30 (iprio0): no trap expect=0x00000000000000ff got=0x0000000000001302
SA-MISMATCH: T-05: M csrr mireg, miselect 0x3E (iprio14): no trap expect=0x00000000000000ff got=0x0000000000001302
RVCP-SUMMARY: TEST FAILED - Test File "u30-aia-a-T-05.S"
RVCP: Test Info: number of SA-MISMATCH soft-check failures (see the log)
Error: Failed stop: Hart 0: write to to-host
=== rv32, ACT config whisper-rv32-mu
SA-MISMATCH: T-05: M csrr mireg, miselect 0x30 (iprio0): no trap (MSLevel.adoc:239-318) expect=0x000000ff got=0x00001302
SA-MISMATCH: T-05: M csrw mireg, miselect 0x30 (iprio0): no trap expect=0x000000ff got=0x00001302
SA-MISMATCH: T-05: M csrr mireg, miselect 0x3E (iprio14): no trap expect=0x000000ff got=0x00001302
SA-MISMATCH: T-05: RV32 M csrr mireg, miselect 0x3F (iprio15): no trap expect=0x000000ff got=0x00001302
RVCP-SUMMARY: TEST FAILED - Test File "u30-aia-a-T-05.S"
RVCP: Test Info: number of SA-MISMATCH soft-check failures (see the log)
Error: Failed stop: Hart 0: write to to-host
```
